# Audit: cctv_false_positive_policy.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/cctv_false_positive_policy.dart` (135 lines) + integration in `lib/application/cctv_bridge_service.dart`
- Read-only: yes

---

## Executive Summary

The file is compact and the core logic is readable, but it contains **two distinct silent-suppression bugs** and **one confidence-threshold semantic that is almost certainly inverted** relative to operator expectations. None of the unit-level paths through `CctvFalsePositiveRule.matches()` are independently tested. The only existing test covers the single happy-path suppression via `cctv_bridge_service_test.dart`. Clock-locality coupling and the `startHour == endHour` wildcard create real failure modes in a production ops environment.

Risk level: **HIGH**. This class gates whether real alarms reach an operator. Silent over-suppression means genuine intrusion events are dropped without any trace.

---

## What Looks Good

- The midnight-crossing inversion (`||` branch at line 55) is structurally correct for wrapping windows.
- `fromJsonString` fails closed (returns empty policy, no suppression) rather than throwing — safe direction on a bad config string.
- `zone` and `objectLabel` both normalize case and trim before comparison (lines 36–37, 22–23).
- `_asInt` and `_asDouble` handle `int`, `num`, and `String` sources cleanly.

---

## Findings

### P1 — `startHourLocal == endHourLocal` silently suppresses ALL hours

- Action: **REVIEW**
- Finding: When `startHourLocal == endHourLocal`, line 50 returns `true` unconditionally — the rule matches every hour of every day for that zone/label combination.
- Why it matters: `_asInt` returns `0` as its fallback (line 61). A JSON rule with null or missing `start_hour_local` **and** `end_hour_local` parses to `CctvFalsePositiveRule(zone: …, objectLabel: …, startHourLocal: 0, endHourLocal: 0)`. That rule then permanently suppresses its zone+label combination regardless of time. An operator who misconfigures or omits the hour fields in the JSON policy gets silent all-day suppression with no warning.
- Evidence: `lib/application/cctv_false_positive_policy.dart:49–51`, `lib/application/cctv_false_positive_policy.dart:58–63`
- Suggested follow-up: Codex should validate whether `start == end` is an intentional "all day" sentinel or a config error. If the intent is "suppress all day," the field should be explicit (e.g., `suppressAllHours: true`). If it is unintentional, the branch should be removed and the caller should treat a 0/0 parse result as a malformed rule to skip.

---

### P1 — `minConfidencePercent` suppresses HIGH-confidence events, not low

- Action: **REVIEW**
- Finding: The check at lines 44–46 reads: `if (confidence < minConfidencePercent) { return false; }`. This means the rule only fires (suppresses) if confidence **is at or above** `minConfidencePercent`. Low-confidence detections are **passed through** and treated as real alarms.
- Why it matters: Operator mental model for a "false positive suppressor" is almost always "ignore low-confidence noise." The implementation does the opposite: it suppresses high-confidence detections of known-benign patterns. The existing test confirms this — `top_score: 0.91` (91%) is suppressed by `minConfidencePercent: 80`. Whether this is correct for the ONYX use case is a product question, but the field name is misleading and there is no documentation. If an operator sets `min_confidence_percent: 40` thinking "ignore alerts below 40%," they will suppress everything above 40% instead.
- Evidence: `lib/application/cctv_false_positive_policy.dart:44–46`, `test/application/cctv_bridge_service_test.dart:391–396`
- Suggested follow-up: Codex should clarify the intended semantics with Zaks. If the current behavior (suppress high-confidence benign patterns) is correct, rename to `appliesAboveConfidencePercent` and add a code comment. If the intent is to suppress low-confidence noise, the comparison direction must be inverted.

---

### P2 — `occurredAtUtc.toLocal()` ties suppression windows to server clock TZ

- Action: **REVIEW**
- Finding: Line 48 uses `occurredAtUtc.toLocal().hour`. In a Flutter web/server context `toLocal()` reflects the process's system timezone, not the site's physical timezone. For ONYX deployments monitoring South African sites from a UTC or Europe-hosted server, the "local hour" used in suppression windows will be wrong.
- Why it matters: A rule intended to suppress car detections at a Johannesburg site between 23:00–05:00 SAST (+2) will, on a UTC server, apply between 21:00–03:00 UTC. During SAST DST transitions (South Africa does not observe DST, but operators copying patterns from UK-based templates may use UTC offset rules), the window drifts silently.
- Load shedding angle: During load shedding outages, DVR/NVR clocks can drift significantly (devices without battery-backed RTC lose time on power cycle). Events timestamped at an incorrect UTC time will be tested against the wrong local hour. If an event generated at 02:00 SAST arrives with a drifted timestamp of 22:00 UTC, the local hour evaluation will evaluate to 00:00 SAST — still within a 23:00–05:00 window, so this specific case is safe. But forward-drift (clock jumps ahead) can place an event outside its window and fail to suppress when it should.
- Clock drift angle: No guard exists against `occurredAtUtc` being in the future (positive drift) or far past (device reset to epoch). Both cases will evaluate the time window check against nonsensical hours.
- Evidence: `lib/application/cctv_false_positive_policy.dart:48`
- Suggested follow-up: Codex should confirm whether the calling sites always pass `occurredAtUtc` in UTC. If a site-specific IANA timezone is available in `OpsIntegrationProfile`, the `matches()` method should accept a `timeZoneId` parameter and use a proper TZ-aware conversion rather than `toLocal()`.

---

### P2 — Zone wildcard via missing/null JSON field silently applies rule to all zones

- Action: **AUTO**
- Finding: `zone: (json['zone'] ?? '').toString().trim().toLowerCase()` (line 22). If the JSON entry omits `zone` or sets it to `null`, `zone` becomes `""`. In `matches()`, line 38–40: `if (zone.isNotEmpty && ...)` — empty zone is a **wildcard that matches all zones**. Same applies to `objectLabel` (line 23).
- Why it matters: An operator who writes `{"object_label": "cat", "start_hour_local": 0, "end_hour_local": 6}` (omitting `zone`) intends "suppress all cats 00:00–06:00" — which is the wildcard behavior and may be intentional. But an operator who makes a JSON typo (`"zonee": "garden"`) will also get a wildcard rule and suppression will silently expand to all zones. No validation or diagnostic exists.
- Evidence: `lib/application/cctv_false_positive_policy.dart:22–23`, `lib/application/cctv_false_positive_policy.dart:38–42`
- Suggested follow-up: Codex should add a `fromJson` validation step that, at minimum, logs a warning when both `zone` and `objectLabel` are empty simultaneously (a rule that wildcards both fields suppresses everything in the time window across the entire site).

---

### P3 — Silent parse failure swallows misconfiguration with no diagnostic

- Action: **AUTO**
- Finding: `fromJsonString` catches all exceptions and returns an empty policy (lines 98–99). Similarly, a non-list JSON root returns an empty policy (lines 84–86). No logging, no error event, no indicator to the caller that the config was invalid.
- Why it matters: If an operator deploys a broken policy string, the system silently operates with **no suppression** — the opposite of the intended behavior. The operator has no feedback. The bug may be discovered only after alert fatigue complaints or a missed alarm incident.
- Evidence: `lib/application/cctv_false_positive_policy.dart:83–100`
- Suggested follow-up: Codex should add a `(CctvFalsePositivePolicy policy, String? parseError)` return type or a named constructor `CctvFalsePositivePolicy.fromJsonStringSafe` that surfaces a non-null `parseError` string for callers to log or display in the admin UI.

---

### P3 — Boundary hour exclusion: `endHourLocal` is exclusive, undocumented

- Action: **AUTO**
- Finding: Line 53 uses `localHour < endHourLocal` (strict less-than). An event at exactly `endHourLocal` (e.g., 06:00 with `endHourLocal=6`) is **not suppressed**. The midnight-crossing branch (line 55) uses the same exclusive upper bound. This is probably intentional (suppress up to but not including the end hour) but is undocumented.
- Why it matters: If an operator intends "suppress until 06:00" they may expect 06:00 events to be suppressed. The field name `endHourLocal` gives no indication of inclusivity. A mismatch between operator intent and implementation could leave the 06:00 hour unsuppressed across all rules.
- Evidence: `lib/application/cctv_false_positive_policy.dart:53, 55`
- Suggested follow-up: Codex should add inline doc to `endHourLocal` clarifying "exclusive upper bound (events at this exact hour are not suppressed)."

---

## Duplication

- The zone/label normalization pattern (`trim().toLowerCase()`) appears in both `fromJson` (lines 22–23) and `matches()` (lines 36–37). The `matches()` re-normalizes inputs that may already be normalized by the caller. No functional bug, but double normalization is noise. Centralize into a `_normalize(String s)` helper.
- Files: `lib/application/cctv_false_positive_policy.dart:22–23, 36–37`

---

## Coverage Gaps

The only test for this subsystem (`cctv_bridge_service_test.dart:355–411`) exercises one path: standard window (00:00–06:00), high-confidence, zone match, label match — suppressed. The following paths are entirely untested:

| Gap | Risk |
|-----|------|
| `startHourLocal == endHourLocal` → always suppresses | **CRITICAL** — silent all-day suppression |
| Midnight-crossing window (`startHour > endHour`) | HIGH — inversion branch never exercised |
| Confidence **below** `minConfidencePercent` → should NOT suppress | HIGH — determines whether low-confidence events leak through |
| `null` confidence input → defaults to `0` (line 44) | MEDIUM — null path never validated |
| Empty `zone` wildcard matches all zones | MEDIUM — wildcard expansion untested |
| Empty `objectLabel` wildcard | MEDIUM |
| Both `zone` and `objectLabel` empty → full site wildcard | HIGH |
| `fromJsonString` with non-list JSON | MEDIUM |
| `fromJsonString` with malformed JSON string | MEDIUM |
| `fromJsonString` with missing `start_hour_local` / `end_hour_local` fields | **CRITICAL** — exercises the 0/0 bug above |
| Event exactly at `endHourLocal` → should NOT suppress | MEDIUM |
| `CctvFalsePositivePolicy.enabled` with empty rules | LOW |
| `summaryLabel()` output format | LOW |
| Multiple rules — first match suppresses, second rule not evaluated | MEDIUM |

### Minimum test suite to catch false-suppression failures

These tests should be on `CctvFalsePositiveRule.matches()` directly (unit tests, no bridge service needed):

1. **Standard window in-range** → suppresses
2. **Standard window out-of-range** → does not suppress
3. **Standard window at boundary hour (`endHourLocal`)** → does not suppress (exclusive)
4. **Midnight-crossing window in-range (past midnight)** → suppresses
5. **Midnight-crossing window in-range (before midnight)** → suppresses
6. **Midnight-crossing window out-of-range (midday)** → does not suppress
7. **`startHour == endHour`** → documents whether this is intentional all-day or a bug
8. **Confidence at threshold** → suppresses
9. **Confidence below threshold** → does NOT suppress
10. **Null confidence with non-null `minConfidencePercent`** → does not suppress (0 < threshold)
11. **Zone wildcard (empty zone)** → matches any zone
12. **Label wildcard (empty label)** → matches any label
13. **Both wildcards** → full-site suppression
14. **`fromJsonString` missing hour fields** → validates behavior with 0/0 default
15. **`fromJsonString` non-list root** → returns empty policy
16. **`fromJsonString` invalid JSON** → returns empty policy

---

## Performance / Stability Notes

- `rules.any(...)` iterates linearly. For the expected rule count (single digits), no concern. If rules ever grow to hundreds, a pre-indexed map by `zone+label` key would reduce hot-path cost. Not a current issue.
- No cooldown or deduplication in this class. Rapid repeat triggers (e.g., persistent motion causing 50 events/minute) all pass through `shouldSuppress` independently per event. The class is stateless so this is architecturally correct — deduplication belongs in `cctv_bridge_service.dart` upstream.

---

## Recommended Fix Order

1. **Clarify `startHour == endHour` semantics** (P1, REVIEW) — product decision required before any code change. This is the highest-risk silent suppression path.
2. **Clarify `minConfidencePercent` direction** (P1, REVIEW) — rename or flip comparison based on confirmed intent. Field semantics affect all downstream rules.
3. **Add missing unit tests for `CctvFalsePositiveRule.matches()`** (Coverage) — AUTO, no product input needed, covers both confirmed behaviors and exposes the `startHour == endHour` behavior for decision.
4. **Surface `fromJsonString` parse failures** (P3, AUTO) — return or log error string so misconfiguration is not invisible.
5. **Add wildcard validation warning** (P2, AUTO) — warn when both `zone` and `objectLabel` are empty.
6. **Document `endHourLocal` exclusivity** (P3, AUTO) — inline comment only.
7. **Replace `toLocal()` with explicit TZ conversion** (P2, REVIEW) — requires confirming whether site-level timezone is available in calling context.
