# Codex Summary — Design Tokens & Component Library
**Date:** 2026-04-08  
**Scope:** `onyx_design_tokens.dart`, `OnyxStatusBanner`, `OnyxPageHeader`

---

## What changed

### `lib/ui/theme/onyx_design_tokens.dart`

Updated `OnyxColorTokens` with Figma-exact values and added new tokens:

| Token | Old | New |
|-------|-----|-----|
| `backgroundPrimary` / `shell` | `0xFF0A0A0F` | `0xFF0A0A0A` |
| `textPrimary` | `0xFFF2F5F7` | `0xFFFFFFFF` |
| `textSecondary` | `0xFF9DA6B4` | `0xFF9CA3AF` |
| `borderSubtle` | `0xFF1E1E2E` | `0xFF1F2937` |
| `accentPurple` | `0xFF7B5EA7` | `0xFF7C3AED` |
| `surfaceCard` | _(new)_ | `0xFF111111` |
| `surfaceElevated` | _(new)_ | `0xFF1A1A1A` |
| `accentTeal` | _(new)_ | `0xFF0D9488` |
| `statusSuccess` | _(new)_ | `0xFF10B981` |
| `statusWarning` | _(new)_ | `0xFFF59E0B` |
| `statusCritical` | _(new)_ | `0xFFEF4444` |
| `statusInfo` | _(new)_ | `0xFF3B82F6` |

Added to `OnyxDesignTokens` aliases:
- `surfaceCard`, `surfaceElevated`
- `accentPurple` (explicit alias, previously only `purpleAdmin` existed)
- `accentTeal`
- `statusSuccess`, `statusWarning`, `statusCritical`, `statusInfo`

---

### `lib/ui/components/onyx_status_banner.dart` _(new)_

`OnyxSeverity` enum: `critical | warning | info | success`

`OnyxStatusBanner` widget:
- Full-width colored banner with left accent border
- Left-side icon + message text (expands to fill width)
- Optional right-side `action` label in accent color
- Background is 10% opacity of the accent color
- Colors driven by `OnyxDesignTokens.status*` tokens

Usage:
```dart
OnyxStatusBanner(
  message: 'Site DELTA offline — last heartbeat 4m ago',
  severity: OnyxSeverity.critical,
  action: 'INVESTIGATE',
)
```

---

### `lib/ui/components/onyx_page_header.dart` _(new)_

`OnyxPageHeader` widget:
- 44×44 rounded-square icon container (10px radius) with tinted background + border
- Title (18px semibold) + subtitle (13px regular) stacked beside icon
- Optional `actions` list appended to the right
- All colors from `OnyxDesignTokens.textPrimary/Secondary`

Usage:
```dart
OnyxPageHeader(
  title: 'Risk Intelligence',
  subtitle: 'Live threat feed — 3 active advisories',
  icon: Icons.shield_outlined,
  iconColor: OnyxDesignTokens.statusCritical,
  actions: [RefreshButton()],
)
```

---

## Analysis result
`dart analyze` — **No issues found** on all three files.
