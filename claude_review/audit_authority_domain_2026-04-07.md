# Audit: Authority Domain

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/authority/` (all 9 files) + `lib/application/onyx_scope_guard.dart` + `lib/application/onyx_telegram_command_gateway.dart` + `test/application/onyx_scope_guard_test.dart`
- Read-only: yes

---

## Executive Summary

The authority domain is structurally clean. The core authorization path — `TelegramRolePolicy` → `OnyxScopeGuard.resolveTelegramScope` → `OnyxScopeGuard.validate` — is coherent and fail-closed by default. Role hierarchy is correctly ordered. Intersection logic is sound.

However there are four material issues that need to be resolved before this can be trusted in production:

1. `propose` and `execute` actions exist in policy but are **never required by any command intent** in the gateway. The action ladder has dead rungs.
2. `AuthorityToken` is a stub with no expiry, revocation, or wiring into any authorization path.
3. `OnyxAuthorityScope.allowsClient` / `allowsSite` silently pass empty strings as wildcard — this is an implicit contract gap that is not tested.
4. `OperatorContext` is defined in the authority domain but is **not wired into the Telegram authorization path** at all.

---

## What Looks Good

- **Role hierarchy is correctly ordered**: guard ≤ client ≤ supervisor ≤ admin. Supervisor is correctly blocked from `execute`. Admin is the only role with the full action set.
- **Intersection-first scope resolution**: `OnyxScopeGuard.resolveTelegramScope` correctly takes the intersection of group binding and user-level allowlists for both client IDs, site IDs, and actions. Narrowest scope wins.
- **Group ID mismatch check**: `OnyxTelegramCommandGateway.route` explicitly blocks requests where `groupBinding.telegramGroupId` does not match `request.telegramGroupId`, preventing a caller from supplying a more-permissive binding for the wrong group.
- **`TelegramScopeBinding` default actions are fail-closed**: The default `allowedActions = {read, propose}` means unconfigured groups cannot stage or execute without explicit opt-in.
- **`OnyxRoute` integrity guards at module load time**: Path uniqueness, label case, badge pairing, and autopilot key format are all validated by `_buildOnyxRoutes`. Misconfiguration fails at startup.
- **Existing test coverage**: `onyx_scope_guard_test.dart` covers the core supervisor/execute boundary, intersection resolution, cross-site denial, and guard execute denial. These are the right tests.

---

## Findings

### P1 — `propose` and `execute` actions are dead rungs in the command gateway

- **Action: DECISION**
- `OnyxTelegramCommandGateway._requiredActionForIntent` maps all intents to either `read` or `stage`. Neither `propose` nor `execute` is ever the required action for any `OnyxCommandIntent`.
  - Evidence: `onyx_telegram_command_gateway.dart:109–121`
  - `OnyxCommandIntent` has 9 values. Only `draftClientUpdate` requires `stage`. The remaining 8 require `read`.
- **Why it matters**: Guard and client roles have `propose` in their policy but it never gates anything. Admin has `execute` but no intent exercises it. This means:
  - The `propose` permission is cosmetic — it gives users a false sense of a meaningful capability boundary.
  - No current command requires admin-only authority (`execute`). Anything an admin can do, a supervisor can also do today.
  - If high-privilege intents are added later without updating `_requiredActionForIntent`, they will silently default to `read` authority.
- **Suggested follow-up for Codex**: Verify whether `propose` and `execute` are reserved for planned intents. If not planned, either (a) remove them from the enum and policy to avoid confusion, or (b) add the missing intents that gate on them so the ladder is complete.

---

### P1 — `AuthorityToken` is a stub with no production integration

- **Action: REVIEW**
- `AuthorityToken` (2 fields: `authorizedBy`, `timestamp`) exists in the authority domain but is not referenced by `OnyxScopeGuard`, `OnyxTelegramCommandGateway`, or any call site in the application layer.
  - Evidence: `authority_token.dart:1–9`. Grep confirms only the domain file itself defines it; no application file imports it.
- **Why it matters**: If `AuthorityToken` is meant to be a session/operation token (e.g. to audit who authorized a sensitive action, or to enforce short-lived authority windows), it is currently a no-op. There is no expiry check, no revocation list, and no audit trail. A token issued at any `timestamp` is indistinguishable from one issued just now.
- **Suggested follow-up for Codex**: Check git history for original intent of `AuthorityToken`. If it was scaffolded for future use, add a `// TODO(authority): not yet wired` comment so reviewers don't mistake it for active enforcement.

---

### P2 — Empty string acts as implicit wildcard in `allowsClient` / `allowsSite`

- **Action: REVIEW**
- `OnyxAuthorityScope.allowsClient('')` returns `true` regardless of `allowedClientIds`. Same for `allowsSite`.
  - Evidence: `onyx_authority_scope.dart:27–30` and `34–38`
- The `validate` guard in `OnyxScopeGuard` pre-filters empty clientId/siteId before calling `allowsClient`/`allowsSite` (lines 57–70 in `onyx_scope_guard.dart`), so the primary path is protected.
- **Why it matters**: Any caller that directly queries `scope.allowsClient('')` — bypassing the guard — gets `true` even when `allowedClientIds` is `{}` (an explicitly empty scope). This is an implicit contract. If the domain object is used outside the gateway in future (e.g. for reporting access or data export), this silent wildcard could allow over-broad access.
- This is a **suspicion-level risk** for the current code paths, but a confirmed contract gap for future callers.
- **Suggested follow-up for Codex**: Add a doc comment to `allowsClient` / `allowsSite` explicitly stating the empty-string contract. Add a test asserting the behaviour.

---

### P2 — `OperatorContext` is defined in authority domain but disconnected from authorization

- **Action: DECISION**
- `OperatorContext` defines `canExecute(regionId, siteId)` using an AND condition (requires both region and site allowlist membership).
  - Evidence: `operator_context.dart:12–18`
- It is not imported or used by `OnyxScopeGuard`, `OnyxTelegramCommandGateway`, or any other application layer file (grep of `OperatorContext` in `/lib` confirms only `authority_token.dart` and `operator_context.dart` are in the authority domain; the application-layer grep shows no usages outside those files except `app_state.dart`).
  - Evidence: `lib/application/app_state.dart` imports it (confirmed by grep result).
- **Why it matters**: It is unclear whether `OperatorContext` is an active authorization concept or a domain stub. If it represents a separate access control plane (e.g. for web dashboard operators vs Telegram users), it needs tests and integration. If it is redundant with `OnyxAuthorityScope`, it should be consolidated.
- **Suggested follow-up for Codex**: Check `app_state.dart` to see how `OperatorContext` is constructed and used. Confirm whether it is gating actual authorization decisions or is carried as passive metadata.

---

### P3 — `guard` and `client` roles are policy-identical with no test asserting the distinction

- **Action: AUTO**
- `TelegramRolePolicy.forRole(OnyxAuthorityRole.guard)` and `TelegramRolePolicy.forRole(OnyxAuthorityRole.client)` produce identical action sets: `{read, propose}`.
  - Evidence: `telegram_role_policy.dart:13–20`
- **Why it matters**: This may be intentional, but it is untested. If a future change differentiates guard from client (e.g. guards can `propose` but clients cannot), the absence of a test asserting current identity means the regression will be silent. The existing `onyx_scope_guard_test.dart` only tests the supervisor/guard boundary.
- **Suggested follow-up for Codex**: Add a test that asserts `guard` and `client` produce the same policy today, making any future change explicit.

---

### P3 — Group mismatch check is post-scope-resolution

- **Action: AUTO**
- In `OnyxTelegramCommandGateway.route`, `scopeGuard.resolveTelegramScope` is called unconditionally at line 68, before the group ID mismatch check at line 77.
  - Evidence: `onyx_telegram_command_gateway.dart:68–88`
- **Why it matters**: Scope resolution is pure computation (no I/O), so this is not a security flaw — the mismatch check still blocks the command. But if scope resolution ever acquires side effects or becomes async, this ordering would be a latent risk. The check should logically precede the work it guards.
- **Suggested follow-up for Codex**: Move the group ID mismatch check to the top of `route()`, before `resolveTelegramScope`. This is a structural alignment fix, not a security patch.

---

## Duplication

- **`_wrongGroupGuidance` vs `_restrictedAccessGuidance`** in `onyx_telegram_command_gateway.dart` and `onyx_scope_guard.dart`:  
  Both methods implement identical per-role message strings with nearly identical patterns.  
  Files: `onyx_scope_guard.dart:85–96`, `onyx_telegram_command_gateway.dart:123–134`  
  Centralization candidate: a single `OnyxAuthorityRole` extension method `accessGuidanceMessage` would unify this.

- **`allowedActions` default `{read, propose}`** appears both as the `TelegramScopeBinding` default and implicitly as the guard/client policy. These are separate sources of the same policy truth, which means a change to guard policy does not automatically propagate to the binding default (and vice versa). They should either be derived from the same constant or explicitly acknowledged as independent.

---

## Coverage Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| No test for `guard` role policy identity to `client` role | Medium | AUTO candidate — assert both produce `{read, propose}` |
| No test for `allowsClient('')` / `allowsSite('')` wildcard behaviour | Medium | REVIEW — clarifies implicit contract |
| No test for empty `allowedClientIds` group binding → empty resolved scope | High | Production config risk — a binding with `allowedClientIds: {}` silently creates a scope where no client commands work |
| No test for `propose` action never being required by any intent | Low | Documents dead rung intentionally |
| No test for `AuthorityToken` at all | Low | Needs at minimum a contract test when wired |
| No test for `OperatorContext.canExecute` | Medium | Both true and false paths untested |
| No test for `OnyxTelegramCommandGateway.route` end-to-end | High | The gateway itself — which wires policy + scope + intent — has no test. `onyx_scope_guard_test.dart` tests the parts but not the composed pipeline |

**Most critical missing test**: `OnyxTelegramCommandGateway.route` end-to-end — a guard attempting `draftClientUpdate` (which requires `stage`), a client in the wrong group, and an admin using a binding that restricts their actions below their role policy.

---

## Performance / Stability Notes

- No material performance concerns. All authority objects are `const`, all resolution is synchronous pure computation, no I/O.
- `OnyxRoute._buildOnyxRoutes` runs at module load time and throws `StateError` on any misconfiguration. This is intentionally eager. No risk unless a route is added with a duplicate label — which the guard catches.

---

## Recommended Fix Order

1. **[DECISION] Clarify `propose`/`execute` dead rungs** — this is a product/architecture question that gates how the authorization model is used going forward. Needs Zaks to decide whether to fill the ladder or trim it.
2. **[HIGH] Add `OnyxTelegramCommandGateway.route` end-to-end test** — the composed gateway path is untested. This is the highest-value test gap.
3. **[HIGH] Add test for empty `allowedClientIds` group binding → empty resolved scope** — a misconfigured binding silently produces a zero-scope principal with no visible error.
4. **[AUTO] Add test asserting `guard` == `client` policy identity** — prevents silent regression.
5. **[AUTO] Move group ID mismatch check before `resolveTelegramScope`** — structural alignment, zero risk.
6. **[REVIEW] Clarify `AuthorityToken` intent and add a doc comment or wire it in** — prevents future reviewers from trusting it as active enforcement.
7. **[DECISION] Audit `OperatorContext` usage in `app_state.dart`** — determine whether it is an active authorization gate or passive metadata.
