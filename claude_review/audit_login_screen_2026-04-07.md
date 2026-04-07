# Audit: Login Screen (controller_login_page.dart)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/controller_login_page.dart`, `lib/main.dart` lines 1683–1709 and 28863–28895
- Read-only: yes

---

## Executive Summary

The login screen works for its demo purpose but has four categories of real risk: a full set of hardcoded light-theme colors with no token anchoring, three font families called directly via `GoogleFonts` bypassing `OnyxTypographyTokens`, plaintext demo passwords visible in the UI on-screen and in source, and zero widget-test coverage. The most urgent item is the plaintext password display in the demo account cards — that pattern must not survive into any production or client-facing build.

---

## What Looks Good

- `TextEditingController` disposed correctly in `dispose()` (lines 47–50).
- `ValueKey` constants on all interactive elements — good for test targeting.
- Password field is correctly `obscureText: true` for keyboard entry.
- `errorBuilder` fallback on the logo `Image.asset` prevents a blank screen if the asset is missing.
- `LayoutBuilder` breakpoint for horizontal padding (`>= 880`) is a reasonable adaptive layout.

---

## Findings

### P1 — Plaintext passwords rendered on screen in demo account cards
- **Action: REVIEW**
- The demo account panel renders `'/ ${account.password}'` as plaintext text inside each account row.
- **Why it matters:** Any user, screenshot, screen-recorder, or shoulder-surfer can read every credential at a glance. If a client or customer ever opens the app in controller mode, all demo passwords are immediately visible. This also conditions operators to accept passwords displayed in plain view.
- **Evidence:** `lib/ui/controller_login_page.dart` line 295–300:
  ```dart
  Text(
    '/ ${account.password}',
    style: GoogleFonts.robotoMono(...),
  ),
  ```
- **Suggested follow-up:** Decide whether the password hint should be removed entirely, replaced with a masked hint (e.g., `'••••••'`), or gated behind `kDebugMode`. This is a product choice (demo UX vs. security posture) so it requires Zaks's call before Codex touches it.

---

### P1 — Plaintext demo credentials in production-reachable source
- **Action: REVIEW**
- `_controllerDemoAccounts` in `main.dart` (lines 1683–1709) stores `password: 'onyx123'` as a compile-time string constant for three accounts with usernames `admin`, `supervisor`, `controller1`. No build flag (`kReleaseMode`, `kDebugMode`, or `--dart-define`) gates this list.
- **Why it matters:** These are not environment-injected values — they are baked into the compiled binary for every build target including production web deploys. Anyone who decompiles the web bundle or reads the JS output can extract them. The name `admin` with full access is the highest-value target.
- **Evidence:** `lib/main.dart` lines 1685–1708. The gate `_showControllerLoginGate` (line 1605–1606) is `true` whenever `initialRouteOverride == null && _appMode == OnyxAppMode.controller`, which is the **default** app mode (line 1137–1140: `defaultValue: 'controller'`).
- **Suggested follow-up:** Either (a) gate `_controllerDemoAccounts` behind `kDebugMode` and substitute empty list or real auth in release, or (b) move credentials to `--dart-define` environment injection. This is an architecture decision requiring Zaks's approval.

---

### P2 — Entire login page uses a private light-theme color system, not OnyxDesignTokens
- **Action: REVIEW**
- The login page defines its own palette of 14 inline `Color(0xFFxxxxxx)` literals. `OnyxDesignTokens` is a dark-theme system (`backgroundPrimary = Color(0xFF0A0A0F)`) — the login page uses `Color(0xFFF7FAFD)` background and `Colors.white` cards. There are no light-theme tokens in `OnyxDesignTokens` or `OnyxColorTokens`.
- **Why it matters:** Any future theme change, brand update, or dark-mode extension of the login page requires hunting 14 scattered hex values. Colors that are close-but-not-equal to token values (e.g., button blue `0xFF1CB8E7` vs. `accentCyan` `0xFF00B4D8`, icon cyan `0xFF27C1F3` vs. `accentCyan` `0xFF00B4D8`) will drift further over time.
- **Evidence — inline color literals in `controller_login_page.dart`:**

  | Line(s) | Hex | Role |
  |---------|-----|------|
  | 96 | `0xFFF7FAFD` | Scaffold background |
  | 127, 265, 366, 428, 432 | `0xFFD4DFEA` | Border / divider |
  | 129, 267 | `0xFFF8FBFF` / `Colors.white` | Card / logo fallback fill |
  | 134–135 | `0xFF27C1F3` | Logo fallback icon |
  | 145, 169, 282 | `0xFF172638` | Text primary |
  | 156, 384 | `0xFF556B80` | Text secondary |
  | 203 | `0xFFF87171` | Error text |
  | 216 | `0xFF1CB8E7` | Primary button fill |
  | 217 | `0xFFF8FCFF` | Button foreground |
  | 244, 309, 313, 419 | `0xFF6C8198` | Muted text / hint / icon |
  | 289, 297 | `0xFF27C1F3` | Role label accent |
  | 329 | `0xFF7F1D1D` | Reset button border |
  | 369 | `0x120E1A2B` | Card box shadow |
  | 421 | `0xFFF5F8FC` | Field fill |

- **Suggested follow-up:** Decide whether the login page should be dark (matching app shell) or light (current). If light, add a `OnyxLightColorTokens` block to `onyx_design_tokens.dart` and port these 14 values there. If dark, remap to existing dark tokens. Either way this is a DECISION before AUTO cleanup.

---

### P2 — Three font families inline, two not covered by OnyxTypographyTokens
- **Action: AUTO**
- `GoogleFonts.rajdhani()` (line 144), `GoogleFonts.inter()` (lines 155, 168, 203, 224, 243, 288, 306, 308, 337, 384, 407, 413), and `GoogleFonts.robotoMono()` (lines 281, 296) are all called directly. `OnyxTypographyTokens.sansFamily = 'Inter'` covers Inter, but `rajdhani` and `robotoMono` have no token counterparts.
- **Why it matters:** `Rajdhani` is used only for the "ONYX SECURITY" hero heading. `RobotoMono` is used for the username and password fields in the demo list. Neither is documented as an intentional second typeface in the token system. If `google_fonts` network access is disabled, both will fall back to system fonts silently.
- **Evidence:** `lib/ui/controller_login_page.dart` lines 144, 281, 296.
- **Suggested follow-up:** Codex can add `monoFamily = 'RobotoMono'` and `displayFamily = 'Rajdhani'` to `OnyxTypographyTokens` (if both are intentional), then replace the three inline `GoogleFonts.*` calls with token references. No product decision needed if the fonts are intentional.

---

### P2 — Authentication logic inconsistency: trimmed password vs. trimmed username
- **Action: AUTO**
- `_submit()` trims both `username` (line 53) and `password` (line 54) from user input. But for password the comparison is against stored `account.password` which is a literal `'onyx123'` — no surrounding whitespace. This is harmless today but the asymmetry means a future credential-store migration that doesn't pre-trim passwords would silently break login for passwords with leading/trailing spaces.
- **Evidence:** `lib/ui/controller_login_page.dart` lines 53–60.
- **Suggested follow-up:** Either always trim both sides of the comparison (`account.password.trim() == password`) or document that stored credentials must never contain surrounding whitespace.

---

### P3 — Error message leaks authentication model
- **Action: REVIEW**
- On failed login, the error text is `'Use one of the demo accounts below to continue.'` (line 65–67). This directly tells any user the system operates on a fixed demo account list, confirming there is no real credential store to attack differently.
- **Why it matters:** Low-severity for a demo system, but if the same string survives into a build where real credentials are expected, it is a misleading instruction and breaks the UX contract.
- **Evidence:** `lib/ui/controller_login_page.dart` line 65–67.
- **Suggested follow-up:** Replace with a generic `'Invalid username or password.'` that works for both demo and real-auth paths.

---

### P3 — No password visibility toggle
- **Action: REVIEW**
- The password field (`_buildField`) has no show/hide toggle. The `obscureText` value is hardcoded `true` with no state flag. Users who mistype can only delete and retype, not verify what they typed.
- **Evidence:** `lib/ui/controller_login_page.dart` lines 390–440, `obscureText` param has no toggle path.
- **Suggested follow-up:** Add an `_obscurePassword` boolean state with a `suffixIcon` `IconButton` to toggle. Standard pattern, Codex can AUTO if the REVIEW flag is removed.

---

### P3 — `_resetPreview` name is misleading
- **Action: AUTO**
- `_resetPreview()` clears the text fields and delegates to `onResetRequested`. The name implies a broader session reset but it is scoped to just the login form. It is called via the "Clear Cache & Reset" button which does imply session clearing — but only the parent `onResetRequested` callback does that work; this method itself only clears form state.
- **Evidence:** `lib/ui/controller_login_page.dart` lines 83–90.
- **Suggested follow-up:** Rename to `_clearLoginForm` or document that `onResetRequested` is responsible for actual session teardown.

---

## Duplication

None within this file. The `_buildCard`, `_buildLabel`, `_buildField` helpers are clean local extractions and not duplicated elsewhere.

Potential duplication suspicion (not confirmed): `_buildField` with `OutlineInputBorder` + `focusedBorder` styling is likely repeated across other form pages. Candidate for a shared `OnyxTextField` widget — but this requires a broader search across `lib/ui/` before marking it as confirmed duplication.

---

## Coverage Gaps

- **No widget test exists for `ControllerLoginPage`** — zero test files reference this widget or `controller-login-page`, `controller-login-username`, `controller-login-password`, or `controller-login-submit` keys.
- Missing test cases:
  - Correct credentials → `onAuthenticated` called with matching account
  - Wrong password → error text shown
  - Wrong username → error text shown
  - Empty fields → error text shown
  - Demo account tap → fills username and password fields
  - Submit via keyboard `done` action → triggers `_submit`
  - `onResetRequested` called when reset button tapped
  - No `demoAccounts` provided → no crash (empty list edge case)

---

## Performance / Stability Notes

- The `for...in` loop in `_submit()` iterates `demoAccounts` on every submit. Negligible for 3 accounts; not a concern unless the list grows large. No action needed.
- `GoogleFonts.rajdhani()`, `.inter()`, `.robotoMono()` are called on every `build()`. Flutter's `GoogleFonts` caches internally but these should eventually move to `TextStyle` constants to avoid per-build allocation. Low priority.

---

## Recommended Fix Order

1. **[P1 REVIEW]** Decide demo password display policy — remove plaintext `'/ ${account.password}'` from the UI or gate it on `kDebugMode`. Blocks production readiness.
2. **[P1 REVIEW]** Gate `_controllerDemoAccounts` behind `kDebugMode` or move to `--dart-define` injection. Blocks production readiness.
3. **[P2 DECISION]** Choose light vs. dark theme for login screen, then extract all 14 inline color literals to `OnyxDesignTokens` (new light tokens or remap to dark tokens).
4. **[P2 AUTO]** Add `monoFamily` and `displayFamily` to `OnyxTypographyTokens`; replace inline `GoogleFonts.rajdhani` and `GoogleFonts.robotoMono` calls with token references.
5. **[P2 AUTO]** Normalize password trim comparison: `account.password.trim() == password`.
6. **[P3 AUTO]** Rename `_resetPreview` → `_clearLoginForm`.
7. **[P3 REVIEW]** Replace demo-specific error string with generic `'Invalid username or password.'`.
8. **[Coverage]** Add a `controller_login_page_widget_test.dart` covering the cases listed above.
