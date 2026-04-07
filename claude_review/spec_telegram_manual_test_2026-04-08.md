# Manual Testing Script: ONYX Telegram Comms — Ms Vallee Residence

- Date: 2026-04-08
- Author: Claude Code
- Scope: End-to-end Telegram comms, all inbound/outbound lanes, specific to Ms Vallee Residence
- Read-only: yes

---

## Before You Begin

### Pre-conditions Checklist

- [ ] Flutter app is running (web or desktop, confirmed no boot errors in console)
- [ ] `config/onyx.local.json` contains a valid `ONYX_BOT_TOKEN` for the test bot
- [ ] `ONYX_TELEGRAM_CLIENT_CHAT_ID` env is set OR at least one active row in `client_messaging_bridge` Supabase table scoped to `clientId=vallee` / `siteId=ms-vallee-residence` (or equivalent IDs for this site)
- [ ] Partner group chat ID is wired in Admin → Telegram → Partner/Supervisor Group
- [ ] You have access to three real Telegram accounts / windows:
  - **Client window** — the Ms Vallee Residence client Telegram group
  - **Admin/supervisor window** — the admin Telegram group wired to this scope
  - **Partner window** — the partner/armed-response Telegram group
- [ ] Check Admin → Telegram Wiring Checklist: all three rows (Client Group, Partner Group, Admin Group) show status `ready` (not `review` or `missing`)
- [ ] Confirm site name resolves correctly: search `dispatch_page.dart` resolution — the site label for `vallee` maps to `Ms Valley Residence`. Be aware the spelling in Telegram messages will use whatever label the app has resolved.
- [ ] Supabase is accessible — at least one guard event and one intelligence event exist for the site.

### Tone Note

Ms Vallee Residence triggers the **residential tone pack** (because the site name contains both "residence" and "vallee"). All quick-action replies from ONYX will use residential-register language ("your home", softer framing). If replies use corporate/enterprise language instead, that is a **tone routing failure** — log it as a bug.

---

## Test Groups

| Group | What It Tests |
|-------|--------------|
| A | Client quick actions (Status / Details / Sleep check) |
| B | Client approval flow (person detected at home) |
| C | Allowance flow (persistent visitor allow) |
| D | Identity intake (visitor / contractor / delivery) |
| E | High-risk escalation (panic / distress / intrusion) |
| F | Lookup questions that must NOT escalate |
| G | AI assistant natural-language routing |
| H | Admin / supervisor command lane |
| I | Partner dispatch lifecycle |
| J | Misconfiguration survival |

---

## Group A — Client Quick Actions

> Send from: **Client window** (Ms Vallee Residence client group)

---

### A-1 — Status

**Send:**
```
Status
```

**Expected response (≤10s):**
A brief site status summary in residential tone. Example shape:
```
Ms Valley Residence — ACTIVE
Monitoring is active. All cameras healthy. No open incidents.
Last guard check-in: [timestamp]
```

**Dashboard check after:**
- Open Live Operations → Command Board
- Confirm the "last client query" or activity log reflects a quick-action event for this site

**Pass:** Response arrives within 10s, contains at minimum: monitoring status label (ACTIVE / STANDBY / UNAVAILABLE), camera health line, no stack trace visible to end user.

**Fail:** No reply within 15s; corporate/enterprise tone ("your operation"); empty response; exception text visible in reply.

---

### A-2 — Details

**Send:**
```
Details
```

**Expected response:**
A fuller status summary including: guard patrol status (last check-in), camera health breakdown, any open incidents or "none open", active watch window.

**Pass:** Response is longer than A-1 (more fields shown). At least one of: guard status line, camera breakdown, incident list.

**Fail:** Same response text as A-1 (Details and Status indistinguishable); no reply.

---

### A-3 — Sleep check

**Send:**
```
Sleep check
```

**Expected response:**
Residential-tone sleep-check copy. When a watch window is active:
```
Sleep check confirmed. Your home is being monitored. Control will run a welfare check at [time]. If anything requires attention before then, message here.
```
When no active watch window:
```
There is no active watch window right now. If you want a manual follow-up before the next window, message here and control will pick it up.
```

**Pass:** Response contains residential-tone language; correctly indicates active vs. inactive window.

**Fail:** Enterprise-tone reply ("your operation" / "your facility"); no reply; error text.

---

### A-4 — Keyboard shortcut via callback

**Action:** Tap the **Status** button from the Telegram reply keyboard (if keyboard is rendered in the client group).

**Expected response:** Same as A-1 — the callback data `client_quick_status` routes to `TelegramClientQuickAction.status`.

**Dashboard check:** No duplicate events (the same action tapped twice should not create two events if idempotency is working).

**Pass:** Reply arrives; visually identical to A-1; keyboard is dismissed after selection.

**Fail:** No reply on button tap (callback_query not handled); keyboard stays pinned after reply.

---

### A-5 — Natural-language status ask

**Send:**
```
Is everything okay at the site?
```

**Expected response:** Site status reply (same shape as A-1) — this phrase must be caught by `parseActionText` NLP matching, not routed to the AI assistant.

**Pass:** Response is structured status format, not AI conversation reply.

**Fail:** AI assistant responds with conversational text ("Sure, let me check for you...") — that means the NLP status path was bypassed.

---

## Group B — Client Approval Flow (Person Alert)

> Trigger context: A person-detection intelligence event is received for Ms Vallee Residence (real event or simulation fixture). The event must meet approval conditions: `shouldNotifyClient=true`, `shouldEscalate=false`, `identityAllowedSignal=false`.

---

### B-1 — Approval keyboard appears

**Trigger:** Person detected at a Ms Vallee Residence camera during monitoring window.

**Expected in client window:**
```
ONYX detected a person at [camera name], [time].
[Optional: face match or plate reference if available]
Please verify: do you recognise this person?
```
Reply keyboard appears with three buttons:
```
[ APPROVE ]  [ REVIEW ]  [ ESCALATE ]
```

**Dashboard check (before responding):**
- Live Operations → Active Board: confirm a pending verification item is open for this event.

**Pass:** Keyboard appears with exactly three buttons in correct order; message contains camera reference and timestamp; dashboard shows pending verification.

**Fail:** No keyboard rendered; keyboard has wrong buttons; no dashboard item.

---

### B-2 — Reply APPROVE

**Send (as keyboard tap or typed):**
```
APPROVE
```

**Expected client response:**
```
ONYX received your approval. Control has logged this person as expected and will continue monitoring.
```

**Expected admin window (simultaneously):**
```
ONYX client verification update
scope=[clientId]/[siteId]
decision=approved
messageKey=tg-watch-verify-...
```

**Dashboard check:**
- The verification item on Live Ops → Active Board is now resolved / closed.
- Sovereign Ledger shows a new approval event with correct timestamp.

**Pass:** Client receives exact confirmation text; admin notified; keyboard dismissed; Active Board item cleared.

**Fail:** Client receives wrong text (e.g., review/escalate copy); admin not notified; keyboard stays visible.

---

### B-3 — Reply REVIEW

**Trigger:** Generate a second person-detection event (or repeat the simulation).

**Send:**
```
REVIEW
```

**Expected client response:**
```
ONYX received your review request. Control will keep the event open for manual review.
```

**Dashboard check:**
- Active Board: item remains open and is marked for review (not resolved).

**Pass:** Item stays open on dashboard; client gets correct copy.

**Fail:** Item closes (was incorrectly treated as an approval); wrong confirmation text.

---

### B-4 — Reply ESCALATE

**Trigger:** Third person-detection event.

**Send:**
```
ESCALATE
```

**Expected client response:**
```
ONYX received your escalation request. Control has been notified for urgent review.
```

**Expected admin window:** Urgent escalation notice for Ms Vallee Residence with event reference.

**Dashboard check:**
- Incident state transitions to escalated / urgent.
- Sovereign Ledger: escalation event chained after the original alert.

**Pass:** Admin notified; incident marked escalated; client gets correct copy.

**Fail:** No admin notification; incident state unchanged; wrong client text.

---

### B-5 — Unrecognised reply text

**Send:**
```
Maybe
```

**Expected:** No approval action taken. ONYX should either ignore the message (routing to AI assistant or NLP path) or reply with a clarification prompt. It must NOT silently record an approval/escalation.

**Dashboard check:** Verification item state unchanged.

**Pass:** Verification item state unchanged; no false decision recorded.

**Fail:** A decision event is written despite unrecognised text.

---

## Group C — Allowance Flow (Persistent Visitor Allow)

> Precondition: The person-detection event must include a `faceMatchId` or `plateNumber` for the ALLOW ONCE / ALWAYS ALLOW keyboard to appear.

---

### C-1 — Allowance keyboard appears

**Trigger:** Person event with face match ID. ONYX presents initial verification keyboard AND, if face match ID is present, a secondary allowance prompt follows the approval:

```
Would you like ONYX to remember this visitor for future visits?
[ ALLOW ONCE ]  [ ALWAYS ALLOW ]
```

**Pass:** Allowance keyboard appears after APPROVE with exactly two buttons.

**Fail:** Keyboard never appears (allowance offer not triggered for face-matched visitors).

---

### C-2 — Reply ALLOW ONCE

**Send:**
```
ALLOW ONCE
```

**Expected:**
```
ONYX logged this as a one-time approved visitor. We will ask again if the same person appears later.
```

**Dashboard check:**
- Visitor is logged in identity registry as a one-time approval.
- A second detection of the same face match ID should trigger a new approval prompt.

**Pass:** Correct confirmation text; one-time flag in registry.

**Fail:** Visitor permanently added to allowlist (treated as ALWAYS ALLOW).

---

### C-3 — Reply ALWAYS ALLOW

**Trigger:** Repeat C-1 scenario with a different face match ID.

**Send:**
```
ALWAYS ALLOW
```

**Expected:**
```
ONYX saved this visitor to the site allowlist and will treat future matches as expected.
```

**Dashboard check:**
- Visitor is on persistent allowlist.
- A second detection of the same face match ID skips the approval prompt (identityAllowedSignal = true).

**Pass:** Correct confirmation text; future alerts with same ID do not prompt approval.

**Fail:** Visitor not saved; future alerts still prompt approval; wrong confirmation text.

---

## Group D — Identity Intake

> Send from: **Client window.** These are proactive messages from the homeowner pre-notifying ONYX about expected visitors.

---

### D-1 — Named visitor arrival

**Send:**
```
Jane Doe is arriving
```

**Expected client response:**
```
ONYX logged this visitor for control review: Jane Doe.
```

**Expected admin window:**
```
ONYX identity intake captured
scope=[clientId]/[siteId]
category=visitor
confidence=[≥0.70]
name=Jane Doe
plate=-
until=-
raw=Jane Doe is arriving
```

**Dashboard check:**
- Identity registry shows a new entry: `Jane Doe`, category=visitor, site=Ms Vallee Residence.

**Pass:** Name extracted correctly; category=visitor; admin notified; dashboard entry exists.

**Fail:** Name blank or wrong; category wrong; no admin notification; no registry entry.

---

### D-2 — Contractor with plate

**Send:**
```
contractor John Smith plate ABC 1234 GP
```

**Expected client response:**
```
ONYX logged this contractor for control review: John Smith • plate ABC1234GP.
```

**Expected admin window:** category=contractor, plate=ABC1234GP (or format normalised to what the regex captures), name=John Smith.

**Pass:** Both name and plate extracted; category=contractor.

**Fail:** Plate not extracted; category=visitor; name blank.

---

### D-3 — Delivery with time window

**Send:**
```
delivery arriving until 14:00
```

**Expected client response:** Includes `until 14:00 UTC` (or equivalent localised time reference).

**Expected admin window:** `until=` field is set to today at 14:00 UTC.

**Pass:** Time window extracted; category=delivery.

**Fail:** `until` field is null/blank; wrong category.

---

### D-4 — Past-midnight time window

**Send (after 23:00 local):**
```
visitor until 01:00
```

**Expected:** `validUntilUtc` is tomorrow at 01:00, not today at 01:00 (which would be in the past).

**Pass:** `until` in admin message is the next calendar day at 01:00.

**Fail:** `until` resolves to a timestamp already in the past.

---

### D-5 — Insufficient identity signal (no name, no plate)

**Send:**
```
family visiting
```

**Expected:** No intake record created. ONYX either ignores the message or routes to AI assistant. No confirmation text for a blank intake.

**Dashboard check:** No new identity registry entry for this message.

**Pass:** No registry entry created; no spurious "ONYX logged this visitor" reply for a blank identity.

**Fail:** Empty intake record created in registry.

---

## Group E — High-Risk Escalation

> Send from: **Client window.** These messages must trigger immediate high-risk handling — do NOT send these during a real security incident. Use a pre-notified test window.

---

### E-1 — Panic keyword

**Send:**
```
HELP!
```

**Expected in client window:** High-risk acknowledgement. Example:
```
ONYX received your alert. Control has been notified. Stay calm and keep this chat open.
```

**Expected admin window:** Immediate high-risk escalation notice with site = Ms Vallee Residence, raw text = "HELP!", timestamp.

**Dashboard check:**
- New incident in Live Operations with severity = high / urgent.
- Sovereign Ledger: high-risk event entry chained.

**Pass:** Admin notified within 5s; incident created; client receives acknowledgement.

**Fail:** No admin notification; message silently routed to AI assistant (conversational reply, no alert).

---

### E-2 — Intrusion report

**Send:**
```
Someone is in my house
```

**Pass:** Same pass criteria as E-1. `someoneInside` pattern matched.

**Fail:** Routed to AI assistant as a general question.

---

### E-3 — Glass break

**Send:**
```
glass breaking
```

**Pass:** High-risk escalation triggered. Admin notified.

**Fail:** Treated as a general question or AI query.

---

### E-4 — Distress string (vowel repeat pattern)

**Send:**
```
aaaa
```

**Expected:** High-risk escalation triggered (distress pattern `normalized.contains('aaaa')`).

**Pass:** Admin notified; incident created.

**Fail:** Message ignored or routed to AI.

---

### E-5 — Armed intruder

**Send:**
```
there is an armed intruder
```

**Pass:** Matches `armed` keyword. High-risk path taken.

**Fail:** Lookup guard suppresses the escalation incorrectly.

---

### E-6 — Active robbery (not historical)

**Send:**
```
I am being robbed
```

**Pass:** `framesCurrentDanger` is true; historical-incident guard does NOT suppress this; high-risk escalation fires.

**Fail:** Historical-review guard incorrectly suppresses the message; no escalation.

---

## Group F — Lookup Questions That Must NOT Escalate

> Send from: **Client window.** These contain high-risk keywords but must be treated as lookup queries, not emergencies. If ONYX incorrectly escalates any of these, log as a bug.

---

### F-1 — Status lookup with police keyword

**Send:**
```
Are there police at this site?
```

**Expected:** Routed to AI assistant or command handler as a status question. No emergency escalation. Admin NOT notified as a high-risk event.

**Pass:** AI or status reply; no incident created.

**Fail:** High-risk escalation triggered; admin receives emergency alert.

---

### F-2 — Bare question with risk keyword

**Send:**
```
Police?
```

**Pass:** Not escalated (bare question lookup suppression active).

**Fail:** Escalated as emergency.

---

### F-3 — Hypothetical escalation question

**Send:**
```
Can you escalate if there is a problem?
```

**Pass:** Not escalated; routed to AI assistant for capability explanation.

**Fail:** Treated as a live emergency.

---

### F-4 — Historical robbery review

**Send:**
```
Were you aware of the armed robbery earlier today?
```

**Pass:** Historical-incident guard fires; no escalation; routed to AI or command handler for review.

**Fail:** `armed` + `robbery` triggers live escalation despite historical framing.

---

### F-5 — Multi-site breach query

**Send:**
```
Have there been any breaches at my residences?
```

**Pass:** Multi-site scope lookup guard fires (`residences`); not escalated.

**Fail:** `breach` keyword triggers emergency path.

---

## Group G — AI Assistant Natural Language Routing

> Send from: **Client window.** These must be routed to the AI assistant lane, not to quick-action or command parsers.

---

### G-1 — Camera complaint

**Send:**
```
My cameras are down
```

**Expected:** AI assistant responds with a contextual camera-health reply. The message must NOT route to the command gateway (which would return a "you don't have permission for this" or "unknown command" message).

**Pass:** Conversational AI reply about camera status; no command-gateway error message.

**Fail:** Command gateway rejects with a permission or unknown-intent error.

---

### G-2 — General question

**Send:**
```
What happened overnight?
```

**Expected:** AI assistant drafts a contextual reply referencing last night's events for Ms Vallee Residence (tone: residential).

**Pass:** Natural-language reply with residential tone; references "your home" not "your site" or "your facility".

**Fail:** Command-gateway rejection; corporate-tone reply; no reply.

---

### G-3 — AI provider fallback observable

**Pre-condition:** For this test only, temporarily configure the AI provider with an invalid API key (e.g., empty OpenAI key). Do NOT do this in a live production environment.

**Send:**
```
Is everything okay tonight?
```

**Expected:** ONYX still replies (heuristic fallback fires). Reply should be a generic but coherent residential-tone holding message rather than a crash or silent drop.

**Pass:** Reply delivered; `usedFallback=true` observable in application logs; no error text visible to client.

**Fail:** No reply at all (silent drop); raw exception text returned to client.

**Restore:** Re-set the valid API key after this test.

---

## Group H — Admin / Supervisor Command Lane

> Send from: **Admin/supervisor window** (the wired admin group for Ms Vallee Residence). These commands require the group to be bound to the correct scope and the sender to have read or greater permission.

---

### H-1 — Show dispatches today

**Send:**
```
show dispatches today
```

**Expected:** A list of today's dispatch events for Ms Vallee Residence, or `"No dispatches recorded today."` if none exist.

**Pass:** Structured dispatch list or empty-state message; response is scoped to today only (no events from prior days).

**Fail:** Events from yesterday appear; no reply; permission denied message from the wrong group.

---

### H-2 — Show unresolved incidents

**Send:**
```
show unresolved incidents
```

**Expected:** List of all open/unresolved incidents for Ms Vallee Residence, or `"No unresolved incidents."`.

**Pass:** Correct list; each entry has an incident reference and site label.

**Fail:** Resolved incidents appear in list; no reply.

---

### H-3 — Show incidents last night

**Send:**
```
show incidents last night
```

**Expected:** Events from the night window (approx. 18:00 prior day → 06:00 today). Site = Ms Vallee Residence.

**Pass:** Only events within the night window are shown; correct site.

**Fail:** Events from wrong date range; events from other sites mixed in.

---

### H-4 — Guard status lookup

**Send:**
```
check status of Guard001
```

**Expected:** Guard name, last check-in timestamp, last known location or patrol stop.

**Pass:** Guard reference resolved; timestamp present; residential-site context correct.

**Fail:** "Guard not found" despite events existing; wrong guard returned.

---

### H-5 — Wrong group rejection (send admin command from client group)

**Action:** Send `show unresolved incidents` from the **client window** (not the admin window).

**Expected:** ONYX returns a rejection or routes the message to the AI assistant, not to the command handler for admin commands. The client should NOT receive a dispatch list. If they receive a role-guidance message, it should be in the appropriate tone for the client role.

**Dashboard check:** No audit trail entry as if an admin command ran for a client-window sender.

**Pass:** Command not executed from client window; client receives a soft redirect or AI assistant reply, not a dispatch list.

**Fail:** Dispatch list returned to client group; cross-role data leak.

---

## Group I — Partner Dispatch Lifecycle

> Pre-condition: An incident exists for Ms Vallee Residence and a dispatch has been sent to the partner Telegram group. The partner group is wired.

---

### I-1 — Dispatch notification received

**Expected in partner window (ONYX sends this):**
```
ONYX Armed Response Dispatch
Site: Ms Valley Residence
[Incident summary]
[Dispatch directive if set]
[Welfare directive if set]
```
Reply keyboard:
```
[ ACCEPT ]  [ ON SITE ]
[ ALL CLEAR ]  [ CANCEL ]
```

**Pass:** Dispatch message contains site name, incident summary; keyboard has correct 2×2 button layout.

**Fail:** No keyboard; wrong site name; keyboard has wrong button labels.

---

### I-2 — ACCEPT

**Send from partner window:**
```
ACCEPT
```

**Expected in partner window:**
```
ONYX confirmed: response accepted for Ms Valley Residence.
```

**Expected in client window:** Status update that an armed response unit has accepted the dispatch.

**Dashboard check:**
- Dispatch item status updated to `accepted`.
- Sovereign Ledger: `PartnerDispatchStatusDeclared` event chained.

**Pass:** Both windows notified; dashboard status updated; ledger entry present.

**Fail:** No client notification; dispatch status unchanged.

---

### I-3 — ON SITE (after ACCEPT)

**Send from partner window:**
```
ON SITE
```

**Expected:**
- Partner receives confirmation.
- Client window notified that unit is on site.
- Dashboard: dispatch status = `onSite`.

**Pass:** Status progresses correctly; both windows updated.

**Fail:** ON SITE rejected because accept check fails; status unchanged.

---

### I-4 — ALL CLEAR (after ON SITE)

**Send from partner window:**
```
ALL CLEAR
```

**Expected:**
- Partner receives confirmation.
- Client: "All clear confirmed for Ms Valley Residence."
- Dashboard: incident can now be closed.

**Pass:** Correct status progression; client notified.

**Fail:** ALL CLEAR rejected; wrong confirmation copy.

---

### I-5 — State-order violation: ON SITE before ACCEPT

**Trigger:** Fresh dispatch (do not send ACCEPT first).

**Send from partner window:**
```
ON SITE
```

**Expected:** ONYX rejects the transition silently or returns `null` resolution — no `onSite` event written.

**Pass:** Dispatch status remains at initial/dispatched; no `onSite` event in ledger.

**Fail:** `onSite` event written without prior `accept`.

---

### I-6 — Double ACCEPT

**Trigger:** After sending ACCEPT (I-2), attempt to send ACCEPT again.

**Send:**
```
ACCEPT
```

**Expected:** Second ACCEPT is rejected; no duplicate `PartnerDispatchStatusDeclared` event.

**Pass:** One `accepted` event in ledger, not two.

**Fail:** Two `accepted` events written; partner receives a second acceptance confirmation.

---

### I-7 — CANCEL

**Trigger:** Fresh dispatch (no prior actions).

**Send from partner window:**
```
CANCEL
```

**Expected:**
- Dispatch status = `cancelled`.
- Client notified: dispatch cancelled.
- Admin group notified.

**Pass:** All three windows receive appropriate messages; status = cancelled in dashboard.

**Fail:** Cancel not processed; no notifications.

---

## Group J — Misconfiguration Survival

---

### J-1 — Empty bot token at boot

**Trigger:** Stop the app. Set `ONYX_BOT_TOKEN` to an empty string. Restart.

**Expected:** App boots without crashing. `UnconfiguredTelegramBridgeService` is active. All push queue items fail cleanly with reason "not configured". No exceptions surface to UI.

**Dashboard check:**
- Admin → Telegram Wiring: bridge status shows `review` or `not configured`.
- No crash dialogs or unhandled exceptions in the console.

**Pass:** App stable; push fails gracefully; no crash.

**Fail:** App crashes on boot or on first push attempt.

**Restore:** Reset valid bot token. Restart app.

---

### J-2 — No Supabase endpoint record and no env fallback

**Trigger:** Ensure `client_messaging_bridge` has no row for `vallee` scope AND `ONYX_TELEGRAM_CLIENT_CHAT_ID` env is empty.

**Expected:** Push coordinator resolves zero targets (`healthLabel: 'no-target'`). All messages go to `smsFallbackCandidates`. No crash.

**Dashboard check:** Push items enter fallback state; no Telegram delivery attempted; no crash.

**Pass:** Fallback triggered; no crash.

**Fail:** App throws NullPointerException or crashes; push silently dropped with no fallback state.

**Restore:** Re-add endpoint record or env value.

---

## Pass / Fail Summary Sheet

Use this table to record results during the test session.

| Test | Pass / Fail | Notes |
|------|-------------|-------|
| A-1 Status | | |
| A-2 Details | | |
| A-3 Sleep check | | |
| A-4 Keyboard callback | | |
| A-5 NLP status ask | | |
| B-1 Approval keyboard | | |
| B-2 APPROVE | | |
| B-3 REVIEW | | |
| B-4 ESCALATE | | |
| B-5 Unrecognised reply | | |
| C-1 Allowance keyboard | | |
| C-2 ALLOW ONCE | | |
| C-3 ALWAYS ALLOW | | |
| D-1 Named visitor | | |
| D-2 Contractor + plate | | |
| D-3 Delivery + time window | | |
| D-4 Past-midnight time | | |
| D-5 Insufficient signal | | |
| E-1 HELP! | | |
| E-2 Someone in my house | | |
| E-3 Glass breaking | | |
| E-4 aaaa distress | | |
| E-5 Armed intruder | | |
| E-6 Active robbery | | |
| F-1 Police lookup | | |
| F-2 Bare police? | | |
| F-3 Hypothetical escalation | | |
| F-4 Historical robbery review | | |
| F-5 Multi-site breach query | | |
| G-1 Camera complaint → AI | | |
| G-2 Overnight question → AI | | |
| G-3 AI fallback observable | | |
| H-1 Dispatches today | | |
| H-2 Unresolved incidents | | |
| H-3 Last night incidents | | |
| H-4 Guard status | | |
| H-5 Admin cmd from client group | | |
| I-1 Dispatch notification | | |
| I-2 ACCEPT | | |
| I-3 ON SITE after ACCEPT | | |
| I-4 ALL CLEAR | | |
| I-5 ON SITE before ACCEPT | | |
| I-6 Double ACCEPT | | |
| I-7 CANCEL | | |
| J-1 Empty bot token | | |
| J-2 No target resolution | | |

---

## Known Issues to Watch For During Testing

These are confirmed or suspected bugs from the audit layer — flag if they manifest during manual testing:

| Issue | What to watch for |
|-------|------------------|
| Silent `catch (_)` in `OpenAiTelegramAiAssistantService` | AI provider fails but client still gets a reply — check `usedFallback` in logs. If no log signal at all, the bug is present. |
| `learnedReplyExamples` dropped in `_fallbackReply` | Heuristic reply style may be inconsistent with prior ONYX examples for this client — note if AI replies feel generic despite past coaching. |
| `fetchUpdates` offset not advancing | If you see the same incoming message trigger two replies (e.g., "Status" returns two responses), the offset dedup is failing. |
| Delivery key not surviving restart | After app restart, if a previously-sent message is re-delivered (duplicate), Supabase key persistence failed. |
| Ms Vallee / Ms Valley name inconsistency | Site name may render as "Ms Valley Residence" (clients_page) or "Ms Vallee Residence" (dispatch_page) depending on which code path resolves the label. Note which string appears in each Telegram message. |
