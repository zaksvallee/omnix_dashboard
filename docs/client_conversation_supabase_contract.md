# Client Conversation Supabase Contract

This document matches the repository contract implemented in:

- [/Users/zaks/omnix_dashboard/lib/application/client_conversation_repository.dart](/Users/zaks/omnix_dashboard/lib/application/client_conversation_repository.dart)

## Tables

### `public.client_conversation_messages`

The repository reads these columns:

- `author`
- `body`
- `room_key`
- `viewer_role`
- `incident_status_label`
- `message_source` (optional during rollout; defaults to `in_app` when absent)
- `message_provider` (optional during rollout; defaults to `in_app` when absent)
- `occurred_at`

The repository writes these columns:

- `client_id`
- `site_id`
- `author`
- `body`
- `room_key`
- `viewer_role`
- `incident_status_label`
- `message_source`
- `message_provider`
- `occurred_at`

Current write behavior:

- read existing rows for the scope
- insert only missing logical messages from the current in-memory list
- do not perform a scope-wide delete before inserting replacement rows
- if `message_source` / `message_provider` are not present on the target schema, retry the safe insert without those columns

Current read behavior:

- select rows matching `client_id` + `site_id`
- order by `occurred_at desc`
- if `message_source` / `message_provider` are not present on the target schema, retry select without those columns and treat both as `in_app`

### `public.client_conversation_acknowledgements`

The repository reads these columns:

- `message_key`
- `channel`
- `acknowledged_by`
- `acknowledged_at`

The repository writes these columns:

- `client_id`
- `site_id`
- `message_key`
- `channel`
- `acknowledged_by`
- `acknowledged_at`

Current write behavior:

- read existing rows for the scope when available
- upsert the current in-memory acknowledgement list using `client_id,site_id,message_key,channel`
- prune stale acknowledgement rows only after the safe write succeeds

Current read behavior:

- select rows matching `client_id` + `site_id`
- order by `acknowledged_at desc`

### `public.client_conversation_push_queue`

The repository reads these columns:

- `message_key`
- `title`
- `body`
- `occurred_at`
- `target_channel`
- `delivery_provider` (optional during rollout; defaults to `in_app` when absent)
- `priority`
- `status`

The repository writes these columns:

- `client_id`
- `site_id`
- `message_key`
- `title`
- `body`
- `occurred_at`
- `target_channel`
- `delivery_provider` (`in_app` or `telegram`)
- `priority`
- `status`

Current write behavior:

- read existing rows for the scope when available
- upsert the current in-memory push queue using `client_id,site_id,message_key`
- prune stale queue rows only after the safe write succeeds
- if `delivery_provider` is not present on the target schema, retry the safe upsert without that column

Current read behavior:

- select rows matching `client_id` + `site_id`
- order by `occurred_at desc`
- if `delivery_provider` is not present on the target schema, retry select without that column and treat provider as `in_app`

### `public.client_conversation_push_sync_state`

The repository reads these columns:

- `status_label`
- `last_synced_at`
- `failure_reason`
- `retry_count`
- `history`
- `probe_status_label`
- `probe_last_run_at`
- `probe_failure_reason`
- `probe_history`

The repository writes these columns:

- `client_id`
- `site_id`
- `status_label`
- `last_synced_at`
- `failure_reason`
- `retry_count`
- `history`
- `probe_status_label`
- `probe_last_run_at`
- `probe_failure_reason`
- `probe_history`

## Required migration

Apply:

- [/Users/zaks/omnix_dashboard/supabase/migrations/20260304_create_client_conversation_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/20260304_create_client_conversation_tables.sql)
- [/Users/zaks/omnix_dashboard/supabase/migrations/202603050005_create_client_conversation_push_queue.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603050005_create_client_conversation_push_queue.sql)
- [/Users/zaks/omnix_dashboard/supabase/migrations/202603050006_create_client_conversation_push_sync_state.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603050006_create_client_conversation_push_sync_state.sql)
- [/Users/zaks/omnix_dashboard/supabase/migrations/202603050007_add_probe_fields_to_client_push_sync_state.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603050007_add_probe_fields_to_client_push_sync_state.sql)
- [/Users/zaks/omnix_dashboard/supabase/migrations/202603120006_add_client_push_delivery_provider.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120006_add_client_push_delivery_provider.sql)
- [/Users/zaks/omnix_dashboard/supabase/migrations/202603120008_add_client_conversation_message_source_provider.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120008_add_client_conversation_message_source_provider.sql)

## Operational note

The current backend repository is wrapped by a fallback repository:

- Supabase is the primary source when available
- SharedPreferences remains the fallback cache

So if the tables or policies are missing, the UI still works locally, but backend sync will silently fall back to local storage.

Telegram bridge delivery behavior:

- outbound Telegram deliveries now resolve chat targets from `public.client_messaging_endpoints` for the active `client_id` + `site_id` (including client-wide endpoints where `site_id` is null)
- if no scoped endpoint is found, runtime falls back to `ONYX_TELEGRAM_CHAT_ID` / `ONYX_TELEGRAM_MESSAGE_THREAD_ID` when provided
- bot authentication still uses `ONYX_TELEGRAM_BOT_TOKEN`
- inbound Telegram AI routing now appends client-lane conversation rows into `public.client_conversation_messages` (inbound client text, AI replies, escalation acknowledgements, and approval-pending control notes)
