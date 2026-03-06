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
- `occurred_at`

The repository writes these columns:

- `client_id`
- `site_id`
- `author`
- `body`
- `room_key`
- `viewer_role`
- `incident_status_label`
- `occurred_at`

Current write behavior:

- delete all rows matching `client_id` + `site_id`
- insert the current in-memory message list

Current read behavior:

- select rows matching `client_id` + `site_id`
- order by `occurred_at desc`

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

- delete all rows matching `client_id` + `site_id`
- insert the current in-memory acknowledgement list

Current read behavior:

- select rows matching `client_id` + `site_id`
- order by `acknowledged_at desc`

## Required migration

Apply:

- [/Users/zaks/omnix_dashboard/supabase/migrations/20260304_create_client_conversation_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/20260304_create_client_conversation_tables.sql)

## Operational note

The current backend repository is wrapped by a fallback repository:

- Supabase is the primary source when available
- SharedPreferences remains the fallback cache

So if the tables or policies are missing, the UI still works locally, but backend sync will silently fall back to local storage.
