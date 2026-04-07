# ONYX Telegram End-to-End Testing Checklist

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: Full Telegram comms flow — outbound push, inbound command processing, AI assistant, partner dispatch, client approval, identity intake, high-risk escalation, authority/scope guard
- Read-only: yes

---

## Overview: The Telegram Comms Flow

The Telegram stack spans seven distinct lanes, all wired through a shared `TelegramBridgeService` (HTTP) and `TelegramBridgeResolver` (target routing). Testing must cover each lane independently, then their intersections.

```
Inbound (getUpdates polling)
  └── TelegramBridgeService.fetchUpdates
        ├── OnyxTelegramCommandGateway        (admin/supervisor commands)
        │     └── OnyxTelegramOperationalCommandService (dispatch/incident data)
        ├── TelegramAiAssistantService         (client AI replies)
        │     └── OnyxFirstTelegramAiAssistantService (cloud → direct → local)
        ├── TelegramClientApprovalService      (APPROVE / REVIEW / ESCALATE)
        ├── TelegramPartnerDispatchService     (ACCEPT / ON SITE / ALL CLEAR / CANCEL)
        ├── TelegramClientQuickActionService   (Status / Details / Sleep check)
        ├── TelegramIdentityIntakeService      (visitor/plate intake)
        └── TelegramHighRiskClassifier         (panic/duress/breach escalation)

Outbound (sendMessages)
  └── TelegramPushCoordinator
        └── TelegramBridgeResolver.resolveClientTargets / resolvePartnerTargets
              ├── ClientMessagingBridgeRepository (Supabase managed endpoints)
              └── Env-level fallback (ONYX_TELEGRAM_CLIENT_CHAT_ID)
        └── TelegramPushSyncCoordinator        (Supabase queue persistence)
        └── TelegramBridgeDeliveryMemory       (dedup / key cap at 200)
```

---

## Section 1 — Transport Layer: `HttpTelegramBridgeService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T1.1 | `sendMessages` with a valid bot token and single text message | HTTP POST to `/botTOKEN/sendMessage`, `ok: true`, message lands in `sent[]`, `telegramMessageIdsByMessageKey` populated | Core delivery path untested |
| T1.2 | `sendMessages` with `messageThreadId` set | `message_thread_id` present in POST body | Thread routing silently broken |
| T1.3 | `sendMessages` with `parseMode: 'HTML'` | `parse_mode` field present in payload | Formatting control broken |
| T1.4 | `sendMessages` with `replyMarkup` set | `reply_markup` field included and JSON-encoded | Keyboard buttons never sent |
| T1.5 | `sendMessages` returns non-2xx HTTP | Message goes to `failed[]`, reason set to extracted Telegram description or `HTTP NNN` | Errors silently dropped |
| T1.6 | `sendMessages` returns `{"ok": false}` on 200 | Message goes to `failed[]` | Auth errors masked |
| T1.7 | `sendMessages` with empty `chatId` | Message goes to `failed[]` with "Missing Telegram chat_id." reason | Silent drop |
| T1.8 | `sendMessages` with photo (bytes + filename) | POST to `/sendPhoto` via multipart, caption and parse_mode set | Photo delivery untested |
| T1.9 | `sendMessages` throws `TimeoutException` | Message goes to `failed[]`, exception message captured as reason | Timeout silently drops all messages |
| T1.10 | `fetchUpdates` parses text message correctly | `TelegramBridgeInboundMessage` fields mapped from raw JSON — chatId, chatType, fromUserId, text, sentAtUtc | Inbound parsing broken |
| T1.11 | `fetchUpdates` parses `callback_query` correctly | `callbackQueryId` set, `text` = callback data, chat from callback.message | Button taps silently ignored |
| T1.12 | `fetchUpdates` skips entries with empty text | Update discarded | Blank messages cause downstream null-guard failures |
| T1.13 | `fetchUpdates` with `offset` parameter | Query string contains `offset=N` | Duplicate processing if offset never advances |
| T1.14 | `fetchUpdates` returns non-2xx | Returns empty list | Should be observable — currently silent |
| T1.15 | `answerCallbackQuery` with valid id | POST to `/answerCallbackQuery`, returns `true` | Inline keyboards never dismissed |
| T1.16 | `answerCallbackQuery` with empty callback id | Returns `false` without making network call | Unnecessary API hit |
| T1.17 | `UnconfiguredTelegramBridgeService.sendMessages` | All messages in `failed[]` with "not configured" reason | Bridge silently drops during misconfiguration |

### What could go wrong

- `_sendPhotoMessage` uses `client.send()` (streams) — if the `http.Client` is mocked for text messages it may reject streaming. Must test photo path separately.
- `disable_web_page_preview: true` is hardcoded. If Telegram API changes this field name the delivery appears to succeed but URLs render with previews.
- Update parsing assumes `callback_query.message` exists — if Telegram sends an inline message without a backing message object the entire update is skipped with `continue` (line 335). There is no logged signal.

---

## Section 2 — Target Resolution: `TelegramBridgeResolver`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T2.1 | `resolveClientTargets` with Supabase records returning a non-partner endpoint | Returns managed endpoint targets, does not fall back to env | Managed config ignored |
| T2.2 | `resolveClientTargets` with no Supabase records | Falls back to env-level `ONYX_TELEGRAM_CLIENT_CHAT_ID` target | No delivery if managed table empty |
| T2.3 | `resolveClientTargets` when Supabase throws | Catches exception, falls back to env target | Exception kills delivery silently |
| T2.4 | `resolveClientTargets` with clientId/siteId mismatch to fallback target | Env fallback returns null, result is empty list | Wrong client receives message |
| T2.5 | `resolvePartnerTargets` with partner record in Supabase | Returns partner target, skips env fallback | Partner dispatch never delivered |
| T2.6 | `resolvePartnerTargets` with empty partner chat id env | Returns empty list | Partner dispatch silently dropped |
| T2.7 | `telegramFallbackTarget` with empty env chat id | Returns null | Must not proceed to delivery with empty chatId |
| T2.8 | Multiple managed endpoints for same scope | Returns all targets, one message per target | Clients with multiple Telegram groups only get one |

---

## Section 3 — Outbound Push Pipeline: `TelegramPushCoordinator`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T3.1 | `selectNewTelegramBridgeCandidates` — only new, fresh, queued items selected | Items already in `previousQueue` skipped; acknowledged/delivered skipped | Duplicate Telegram messages |
| T3.2 | `selectNewTelegramBridgeCandidates` with `bridgeFallbackToInApp: true` | Returns empty unless `forceResend` | Bridge correctly suppressed during fallback |
| T3.3 | `forwardPushQueueToTelegram` — all sends succeed | `healthLabel: 'ok'`, `smsFallbackCandidates` empty, `deliveredMessageKeysByScope` populated | Delivered keys not persisted → re-delivery on next cycle |
| T3.4 | `forwardPushQueueToTelegram` — some sends fail (non-blocked) | `healthLabel: 'degraded'`, failed items in `smsFallbackCandidates` | Fallback never triggered |
| T3.5 | `forwardPushQueueToTelegram` — failure reason matches `isBlockedReason` | `healthLabel: 'blocked'`, `fallbackToInApp: true` | Bot-banned state not detected |
| T3.6 | `forwardPushQueueToTelegram` — no targets resolved for any candidate | `healthLabel: 'no-target'`, `fallbackToInApp: true` | All messages silently dropped |
| T3.7 | `forwardPushQueueToTelegram` — bridge not configured | `attemptStatus: 'telegram-disabled'`, all candidates in `smsFallbackCandidates` | Disabled bridge silently swallows queue |
| T3.8 | `forwardPushQueueToTelegram` — bridge throws during `sendMessages` | `healthLabel: 'degraded'`, `attemptStatus: 'telegram-failed'` | Unhandled throw crashes coordinator |
| T3.9 | `forwardPushQueueToTelegram` — `allowPreviouslyDelivered: false` with known key | Already-delivered key skipped | Idempotency not enforced |
| T3.10 | `_mergeDeliveredMessageKeysByScope` — scopeKey with bad format (no `|`) | Entry silently skipped | Dedup memory never updated |
| T3.11 | Message key format `{bridgeKey}:{chatId}:{threadId}` constructed correctly | Verified by asserting `outbound[0].messageKey` | Keys differ between threads → dedup fails |
| T3.12 | Multi-site queue — targets resolved per scope and cached | Target resolution called once per scope, not once per item | N+1 Supabase reads |

---

## Section 4 — Delivery Memory: `TelegramBridgeDeliveryMemory`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T4.1 | `mergeDeliveredMessageKeys` — new keys prepended, old keys appended | Delivered keys appear before existing in output | FIFO order violated |
| T4.2 | `mergeDeliveredMessageKeys` — deduplicates across both sets | No key appears twice | Re-delivery with duplicate keys |
| T4.3 | `mergeDeliveredMessageKeys` — trims to limit (default 200) | Output length ≤ 200 | Memory grows unbounded in Supabase |
| T4.4 | `mergeDeliveredMessageKeys` — limit exceeded by delivered alone | Truncated at limit without panic | Large batch breaks |
| T4.5 | Empty strings in existing keys | Stripped by `.trim()` check | Empty string matches no real key (correct) |

---

## Section 5 — Inbound Command Gateway: `OnyxTelegramCommandGateway`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T5.1 | Request from correct group, role with `read` permission, `showUnresolvedIncidents` intent | `allowed: true`, `requiredAction: read` | |
| T5.2 | Request from wrong group | `allowed: false`, guidance message contains role-appropriate hint | Group spoofing not blocked |
| T5.3 | `draftClientUpdate` intent requires `stage` action | Guard validates stage permission, client role rejected | Clients can trigger drafts |
| T5.4 | Group binding has `allowedClientIds` that doesn't include `requestedClientId` | `allowed: false` | Cross-client data leak |
| T5.5 | All `OnyxCommandIntent` values map to a valid `OnyxAuthorityAction` | No `_` wildcard match falls through | New intent added without action binding |
| T5.6 | `_wrongGroupGuidance` returns correct hint for each role | Non-empty string for all four roles | Blank guidance on rejection |

---

## Section 6 — Operational Commands: `OnyxTelegramOperationalCommandService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T6.1 | `guardStatusLookup` with events containing a recent patrol | Response contains guard name and check-in timestamp | Guard status always shows "unknown" |
| T6.2 | `guardStatusLookup` with no patrol events | Response indicates no guard activity on record | Nil crash |
| T6.3 | `showUnresolvedIncidents` with multiple open incidents | Response lists all open incidents with site reference | Silent truncation |
| T6.4 | `showDispatchesToday` — filters to current day only | Events from prior days excluded | Yesterday's incidents bleed in |
| T6.5 | `showIncidentsLastNight` — correct night window | Events between ~18:00 prior day and 06:00 today | Window logic off-by-one |
| T6.6 | `showSiteMostAlertsThisWeek` — site with highest alert count returned | Correct site label in response | Wrong site reported |
| T6.7 | `summarizeIncident` — incident exists, camera health packet attached | Response includes incident summary + camera state | No camera context in reply |
| T6.8 | Unhandled intent routes to fallback message | `handled: false`, `allowed: true`, fallback copy returned | Uncovered intent panics |
| T6.9 | Gateway returns `allowed: false` | Service wraps denial message and returns `allowed: false` | Error message from gateway lost |

---

## Section 7 — AI Assistant Service: `TelegramAiAssistantService`

> Note: The full service (`telegram_ai_assistant_service.dart`, ~5375 lines) has a confirmed P1 bug (silent `catch (_)`) and a parameter omission (`learnedReplyExamples` dropped in `_fallbackReply`). These are flagged in `audit_telegram_ai_assistant_service_dart_2026-04-07.md`. Tests in this section must verify both the happy path and these failure modes.

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T7.1 | `OnyxFirstTelegramAiAssistantService` — cloud boost configured, returns valid reply | Reply used, `providerLabel` = cloud label | Cloud ignored |
| T7.2 | Cloud boost returns null → direct provider (OpenAI) picks up | `providerLabel` = `openai` or similar | Provider chain short-circuits |
| T7.3 | Cloud boost and direct provider both fail → `OnyxLocalBrainService` drafts reply | `providerLabel` = local label | Local fallback never exercised |
| T7.4 | `OpenAiTelegramAiAssistantService` receives `TimeoutException` | Currently: silent fallback, `usedFallback: true`. After fix: error type observable | P1 bug — confirm fix lands |
| T7.5 | AI returns mechanical/template reply (`_looksMechanicalClientReply` matches) | `_polishReply` routes to `_fallbackReply` | Mechanical text leaks to client |
| T7.6 | `_fallbackReply` called with `learnedReplyExamples` non-empty | After fix: examples forwarded. Currently: silently dropped | P1 bug — learned style lost |
| T7.7 | `draftReply` with `audience: admin` vs `audience: client` | System prompt, tone, and context fields differ between audiences | Admin gets client-framed reply |
| T7.8 | `draftReply` with `deliveryMode: approvalDraft` | Reply formatted for approval workflow, not live delivery | Draft mode ignored |
| T7.9 | `draftReply` with populated `cameraHealthFactPacket` | Camera state injected into prompt context | Camera health silently omitted |
| T7.10 | `UnconfiguredTelegramAiAssistantService.draftReply` | Returns `isConfigured: false`, fallback text | Null pointer on unconfigured boot |
| T7.11 | `shouldPreferTelegramAiOverOnyxCommand` — quick-action text detected | Returns `true`, AI assistant takes priority | Command gateway blocks AI lane |
| T7.12 | `shouldPreferTelegramAiOverOnyxCommand` — camera correction phrase | Returns `true` for "my cameras are down" | Correction sent to wrong handler |
| T7.13 | `shouldPreferTelegramAiOverOnyxCommand` — empty prompt | Returns `false` | Null/empty crash |

---

## Section 8 — Client Approval Flow: `TelegramClientApprovalService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T8.1 | `requiresClientApproval` — human-like signal, no escalation, not already allowed | Returns `true` | Approval never triggered |
| T8.2 | `requiresClientApproval` — assessment says `shouldEscalate: true` | Returns `false` — no approval for escalations | Client asked to approve an escalation |
| T8.3 | `requiresClientApproval` — `identityAllowedSignal: true` | Returns `false` — known visitor bypasses approval | Known visitor still interrupts |
| T8.4 | `parseDecisionText` — all canonical approval strings | Correct `TelegramClientApprovalDecision` enum value returned | Mis-parsed approval causes wrong state |
| T8.5 | `parseDecisionText` — unrecognized string | Returns `null` | Null crash in caller |
| T8.6 | `parseAllowanceDecisionText` — "ALLOW ONCE" vs "ALWAYS ALLOW" | Correct enum variant returned | Persistent allowance created instead of one-time |
| T8.7 | `canOfferPersistentAllowance` — face match id present | Returns `true` | Allowance offer never shown |
| T8.8 | `clientConfirmationText` and `adminDecisionSummary` for all three decisions | Non-empty, correct content per decision | Wrong confirmation text sent |
| T8.9 | `isVerificationMessageKey` / `isAllowanceMessageKey` — correct prefix matching | Correct prefix distinguishes message types | Approval parsed as allowance |
| T8.10 | `replyKeyboardMarkup` — structure | Contains APPROVE / REVIEW / ESCALATE as top-row buttons | Keyboard never sent or wrong options |

---

## Section 9 — Partner Dispatch: `TelegramPartnerDispatchService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T9.1 | `parseActionText` — all canonical strings ("accept", "ack", "en route") | Returns correct `TelegramPartnerDispatchAction` | Typo in reply kills dispatch loop |
| T9.2 | `parseActionText` — unrecognized string | Returns `null` | Null crash in caller |
| T9.3 | `resolveReply` — dispatch does not exist in events | Returns `null` | Phantom dispatch actions accepted |
| T9.4 | `resolveReply` — dispatch already closed (IncidentClosed or ExecutionDenied) | Returns `null` | Actions accepted on closed incident |
| T9.5 | `resolveReply` — `onSite` attempted before `accept` (no verified arrival) | Returns `null`, transition rejected | Status order violated |
| T9.6 | `resolveReply` — `onSite` with verified `ResponseArrived` but no `accept` | Allowed — ResponseArrived bypasses accept requirement | Partner arrival blocked |
| T9.7 | `resolveReply` — `allClear` before `onSite` | Returns `null` | All-clear accepted before arrival |
| T9.8 | `resolveReply` — double `accept` attempt | Returns `null` on second attempt | Duplicate accepted events |
| T9.9 | `resolveReply` — valid ACCEPT | Returns `TelegramPartnerDispatchResolution` with correct `PartnerDispatchStatusDeclared` event | |
| T9.10 | `buildDispatchMessage` — directive fields empty | Empty directive lines omitted from output | Blank lines in dispatch message |
| T9.11 | `replyKeyboardMarkup` — structure | 2×2 grid: ACCEPT / ON SITE / ALL CLEAR / CANCEL | Wrong buttons on dispatch notification |

---

## Section 10 — Client Quick Actions: `TelegramClientQuickActionService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T10.1 | "Status" → `TelegramClientQuickAction.status` | Correct parse | |
| T10.2 | "Details" / "details here" → `statusFull` | Correct parse | |
| T10.3 | "Sleep check" / "bedtime check" → `sleepCheck` | Correct parse | |
| T10.4 | Explicit shortcut `client_quick_status_full` | Parsed from keyboard callback | Inline keyboard buttons break |
| T10.5 | Natural language status ask (via `parseActionText`) | Matched by semantic phrase list | NLP path never tested |
| T10.6 | Unrecognized text | Returns `null` | Wrong routing to AI lane |
| T10.7 | `replyKeyboardMarkup` structure | Status / Details / Sleep check rows | Wrong keyboard |

---

## Section 11 — Identity Intake: `TelegramIdentityIntakeService`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T11.1 | "John Smith is arriving" | `displayName: "John Smith"`, `category: visitor` | Name extraction broken |
| T11.2 | "contractor ABC 12345" | `plateNumber: "ABC12345"` extracted | Plate never stored |
| T11.3 | "visitor Jane Doe until 22:00" | `validUntilUtc` set to 22:00 of the same day | Time window ignored |
| T11.4 | "until 02:00" when current time is 23:00 | `validUntilUtc` set to next day 02:00 | Past midnight wraps to today instead of tomorrow |
| T11.5 | "family visiting" with no name and no plate | Returns `null` — insufficient identity signal | Empty intake record stored |
| T11.6 | "delivery ABC123" | Category = delivery, plate extracted | Wrong category |
| T11.7 | `aiConfidence` scoring — all signals present | Score ≥ 0.96 capped at 0.96 | Confidence overflow |
| T11.8 | `_extractDisplayName` — leading question word ("What visitor") | Returns empty string | Hallucinated name stored |

---

## Section 12 — High-Risk Classifier: `TelegramHighRiskClassifier`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T12.1 | "police" | `isHighRiskMessage: true` | Keyword not matched |
| T12.2 | "are there police at this site?" | `isHighRiskMessage: false` — lookup question suppresses risk | Lookup question escalated |
| T12.3 | "call police now" | `isHighRiskMessage: true` — assertsActiveIncident overrides lookup guard | Live emergency treated as status query |
| T12.4 | "were you aware of the armed robbery earlier today?" | `isHighRiskMessage: false` — historical review | Historical robbery triggers live escalation |
| T12.5 | "can you escalate if there is a problem?" | `isHighRiskMessage: false` — hypothetical question | Hypothetical triggers escalation |
| T12.6 | "help!" | `isHighRiskMessage: true` — distress pattern | Panic message ignored |
| T12.7 | "someone is in my house" | `isHighRiskMessage: true` | Home intrusion not escalated |
| T12.8 | "glass breaking" | `isHighRiskMessage: true` | Audio threat not detected |
| T12.9 | "I was robbed" | `isHighRiskMessage: true` | Robbery report ignored |
| T12.10 | "robbery?" (bare question) | `isHighRiskMessage: false` — bare question in scoped lookup | Lookup question triggers escalation |
| T12.11 | Empty string | `isHighRiskMessage: false` — no crash | |

---

## Section 13 — Sync / Persistence: `TelegramPushSyncCoordinator`

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T13.1 | `persistPushQueueForScope` — repository resolves, `savePushQueue` succeeds | Returns `PushSyncSuccess` with persisted queue | Queue never written to Supabase |
| T13.2 | `persistPushQueueForScope` — repository resolver returns `null` | Returns `PushSyncRepoMissing` | Queue silently discarded |
| T13.3 | `persistPushQueueForScope` — `savePushQueue` throws | Returns `PushSyncPersistFailed`, error captured | Crash on Supabase write failure |
| T13.4 | `persistPushQueueForScope` — queue saved but sync state write fails | Returns `PushSyncStateWriteFailed`, queue was persisted | State and queue out of sync |
| T13.5 | `clientId` and `siteId` trimmed before resolver call | Whitespace stripped | Wrong repo resolved for " clientA " |

---

## Section 14 — Scope / Authority Layer

### What to test

| # | Scenario | Expected Outcome | Risk if Missing |
|---|----------|-----------------|-----------------|
| T14.1 | `TelegramRolePolicy.forRole(guard)` | `allowedActions` = {read, propose} only | Guard gains stage access |
| T14.2 | `TelegramRolePolicy.forRole(admin)` | `allowedActions` = all four actions | Admin blocked from staging |
| T14.3 | `TelegramScopeBinding` with mismatched `telegramGroupId` in gateway | Gateway rejects before scope validation runs | Group check bypassed |
| T14.4 | `OnyxScopeGuard.resolveTelegramScope` — user allowed for client + site | Scope returned with correct client/site set | Cross-site access granted |
| T14.5 | `OnyxScopeGuard.validate` — action not in scope's allowed set | `allowed: false` with actionable reason message | Unauthorized action allowed |

---

## Section 15 — End-to-End Integration Scenarios

These are the full-stack paths that should be verified with integration or route-level widget tests, not just unit tests.

| # | Scenario | Coverage Needed |
|---|----------|-----------------|
| E1 | **Client sends "Status"** → quick action parsed → site status reply sent via Telegram | Widget test: `onyx_app_clients_route_widget_test` confirms full reply chain |
| E2 | **Intelligence event arrives → push item queued → TelegramPushCoordinator dispatches → Supabase key persisted** | Integration test confirming delivered key survives restart cycle |
| E3 | **Client sends "ESCALATE" on a person alert → TelegramClientApprovalService parses → decision event written → admin Telegram notified** | Full approval cycle test |
| E4 | **Partner dispatch sent via Telegram → partner replies "ON SITE" → `PartnerDispatchStatusDeclared` event created → client Telegram updated** | Partner lifecycle widget test |
| E5 | **Client types "my cameras are down" → routed to AI assistant (not command gateway) → AI reply delivered** | Router policy + AI path |
| E6 | **AI provider throws `TimeoutException` → reply falls back to heuristic → `usedFallback: true` observable in result** | Tests P1 silent-catch bug (blocked until fix) |
| E7 | **Message sent to wrong Telegram group → gateway rejects with role-appropriate guidance** | Wrong-group path covered for each role |
| E8 | **Bot token is empty at boot → `UnconfiguredTelegramBridgeService` used → all sends fail cleanly, no crash** | Misconfiguration survival |
| E9 | **Identity intake: "John Smith arriving" → `TelegramIdentityIntakeService` parses → admin summary sent → client acknowledgement returned** | Intake-to-Supabase write confirmed |
| E10 | **Delivery memory at 199 keys → one more delivery → memory capped at 200, oldest dropped** | Memory cap enforced in real cycle |

---

## Section 16 — Live Smoke Test Protocol

The script `scripts/telegram_quick_action_live_smoke.sh` provides a live smoke harness. Use this for pre-release validation.

### Pre-conditions

- [ ] `config/onyx.local.json` populated with real bot token, `ONYX_TELEGRAM_CLIENT_CHAT_ID`, at least one managed Supabase endpoint record
- [ ] Supabase project accessible and `client_messaging_bridge` table contains at least one active endpoint row
- [ ] Flutter web app boots cleanly on `--web-port 63123`
- [ ] Telegram client chat accessible from a real Telegram account

### Live Smoke Steps

| Step | Action | Expected |
|------|--------|----------|
| S1 | Send "Status" from real Telegram client thread | ONYX replies with site status summary within 10s |
| S2 | Send "Details" | ONYX replies with full status detail |
| S3 | Send "Sleep check" | ONYX replies with sleep-check confirmation copy |
| S4 | Send "show dispatches today" from admin/supervisor Telegram group | ONYX replies with today's dispatch list |
| S5 | Send "show unresolved incidents" | ONYX returns open incident list (or "none") |
| S6 | Trigger a person detection intelligence event (or use simulation fixture) | Approval keyboard appears in client Telegram thread |
| S7 | Reply "APPROVE" to approval keyboard | ONYX confirms approval, keyboard dismissed, admin thread updated |
| S8 | Reply "ESCALATE" to a second approval prompt | ONYX escalates, admin notified |
| S9 | Send a dispatch to partner Telegram group | Reply keyboard shows ACCEPT / ON SITE / ALL CLEAR / CANCEL |
| S10 | Reply "ACCEPT" from partner group | ONYX confirms, dispatch status updated to accepted |
| S11 | Send "visitor Jane Doe arriving" from client thread | ONYX acknowledges, admin receives identity intake summary |
| S12 | Send "HELP!" from client thread | ONYX sends high-risk escalation response; admin notified |
| S13 | Kill and restart app during active push cycle | Delivered message keys survive restart (Supabase sync); no duplicate delivery |
| S14 | Set `ONYX_BOT_TOKEN` to empty string and restart | `UnconfiguredTelegramBridgeService` active, no crashes, push fails cleanly |

### `watch_telegram_updates.py` flags to monitor

- `--telegram-polls 24` at 5-second intervals covers ~2 minutes of live smoke
- Watch for duplicate update_ids in consecutive polls (missing offset advance)
- Watch for `update_id` ever going backwards (update deduplication logic not tested in unit layer)

---

## Section 17 — Known Gaps and Risks (Summary)

| Gap | Risk | Category |
|-----|------|----------|
| Silent `catch (_)` in `OpenAiTelegramAiAssistantService` | All API failures silently fall back; no operational visibility | P1 Bug (unresolved) |
| `learnedReplyExamples` not forwarded in `_fallbackReply` | Learned approval style silently lost on AI polish fallback | P1 Bug (unresolved) |
| No test for `fetchUpdates` offset advancing correctly | Update IDs processed twice on restart → duplicate inbound processing | Coverage gap |
| No test for `callback_query` with missing `.message` field | Silent `continue` — button tap produces no action | Coverage gap |
| No integration test for delivery key surviving app restart | Delivered keys may reset if Supabase write fails silently | Coverage gap |
| `_mergeDeliveredMessageKeysByScope` skips invalid scopeKey format silently | Dedup never updated for malformed scope keys | Coverage gap |
| Photo delivery path (`_sendPhotoMessage`) not covered by unit tests | Photo messages broken silently | Coverage gap |
| `TelegramPushSyncCoordinator` state-write-fails path (`PushSyncStateWriteFailed`) | Queue and sync state diverge after Supabase partial failure | Coverage gap |
| `OnyxFirstTelegramAiAssistantService` priority order (cloud → direct → local) | If intentional, needs a comment; if not, direct provider may preempt local Onyx | REVIEW needed |
| `TelegramIdentityIntakeService` plate regex only handles `XX NNN[NNN]XX` format | Non-standard plates (numeric-only, 4-char prefix) silently not extracted | Coverage gap |
| High-risk classifier has no test for `"aaaa"` pattern | Distress detection via vowel repeat — no unit coverage, undefined boundary | Coverage gap |

---

## Fix Priority Order

1. **Cover `fetchUpdates` offset advance** — prevents duplicate inbound processing on restart
2. **Cover `_sendPhotoMessage`** — photo delivery is entirely untested
3. **Cover `PushSyncStateWriteFailed`** — queue/state divergence is a live data integrity risk
4. **Add integration test for delivery key persistence** — dedup only works if keys survive restart
5. **Fix P1 silent `catch (_)` in AI assistant** (implementation via Codex after REVIEW)
6. **Fix P1 `learnedReplyExamples` omission** (implementation via Codex after REVIEW)
7. **Add `callback_query` missing message field test** — defensive inbound parsing
8. **Clarify `OnyxFirstTelegramAiAssistantService` priority order** — requires DECISION from Zaks
