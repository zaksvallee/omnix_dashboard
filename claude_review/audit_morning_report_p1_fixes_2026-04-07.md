# Audit: morning_sovereign_report_service — P1 Bug Findings

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/morning_sovereign_report_service.dart`
- Read-only: yes

---

## Executive Summary

Three confirmed P1 bugs in `morning_sovereign_report_service.dart`. All are silent
correctness failures: one data integrity bug that silently misclassifies unknown
partner statuses, one swallowed exception that hides ledger verification failures,
and one binary score that mis-represents ledger health as a percentage in the report
output. None are detectable at runtime without deliberate inspection.

---

## What Looks Good

- The `ReplayConsistencyVerifier.verify` call is correctly isolated from the rest of
  report generation — a verification failure cannot crash the report build.
- Shift window filtering logic is sound: both `isBefore` guards are correct and the
  `toUtc()` normalisation is consistently applied.
- `_partnerDispatchStatusLabel` is a clean, exhaustive switch with no default arm —
  correct approach for the label formatter.

---

## Findings

### P1 — Bug 1: `_partnerDispatchStatusFromName` defaults unknown names to `accepted`

- **Action: AUTO**
- **Finding:** The wildcard arm of `_partnerDispatchStatusFromName` returns
  `PartnerDispatchStatus.accepted` for any unrecognised string, including the empty
  string produced when `latestStatus` is absent from a JSON payload.
- **Why it matters:** An unknown or missing status is silently promoted to `accepted`,
  the highest-confidence dispatch state. Any downstream report table, partner
  progression view, or compliance check that reads `latestStatus` will silently
  display `ACCEPT` for partners whose real status is unknown. This is a data integrity
  bug that will corrupt sovereign report output and any audit trail that references it.
- **Evidence:**
  - `lib/application/morning_sovereign_report_service.dart:3143–3153`
  ```dart
  PartnerDispatchStatus _partnerDispatchStatusFromName(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'accepted'  => PartnerDispatchStatus.accepted,
      'onsite'    => PartnerDispatchStatus.onSite,
      'on_site'   => PartnerDispatchStatus.onSite,
      'allclear'  => PartnerDispatchStatus.allClear,
      'all_clear' => PartnerDispatchStatus.allClear,
      'cancelled' => PartnerDispatchStatus.cancelled,
      'canceled'  => PartnerDispatchStatus.cancelled,
      _           => PartnerDispatchStatus.accepted,   // ← BUG
    };
  }
  ```
  - Called at lines 982–984 and 1065–1067 in `fromJson` paths for
    `SovereignReportPartnerScopeBreakdown` and the partner progression entry.
- **Blocker:** `PartnerDispatchStatus` enum
  (`lib/domain/events/partner_dispatch_status_declared.dart:3`) does not currently
  have an `unknown` variant:
  ```dart
  enum PartnerDispatchStatus { accepted, onSite, allClear, cancelled }
  ```
  Codex must add `unknown` to the enum before the default arm can be fixed. The
  label formatter (`_partnerDispatchStatusLabel`) is an exhaustive switch and will
  also need a branch for the new variant.
- **Suggested follow-up for Codex:**
  1. Add `unknown` to `PartnerDispatchStatus` in
     `lib/domain/events/partner_dispatch_status_declared.dart`.
  2. Add `PartnerDispatchStatus.unknown => 'UNKNOWN'` to `_partnerDispatchStatusLabel`.
  3. Change the wildcard arm of `_partnerDispatchStatusFromName` to
     `_ => PartnerDispatchStatus.unknown`.
  4. Verify no downstream switch on `PartnerDispatchStatus` is non-exhaustive after
     adding the new variant (the Dart analyzer will flag these).

---

### P1 — Bug 2: Silent `catch (_)` swallows ledger verification errors without logging

- **Action: AUTO**
- **Finding:** The `catch (_)` block at line 1544 suppresses all exceptions thrown by
  `ReplayConsistencyVerifier.verify` with no diagnostic output. The verifier failure
  is only surfaced as a boolean flag (`replayVerified = false`) that feeds into the
  report — the underlying error cause is permanently lost.
- **Why it matters:** Operators reading a morning report with `hashVerified: false`
  have no way to distinguish a data consistency failure, a replay ordering issue, a
  thrown `StateError`, or a null-safety exception inside the verifier. Silent failures
  in integrity verification are exactly the class of bug that goes undiagnosed for
  weeks. Logging the error is the minimum required to make this diagnosable.
- **Evidence:**
  - `lib/application/morning_sovereign_report_service.dart:1541–1546`
  ```dart
  var replayVerified = true;
  try {
    ReplayConsistencyVerifier.verify(nightEvents);
  } catch (_) {          // ← exception type and message are discarded
    replayVerified = false;
  }
  ```
- **Suggested follow-up for Codex:**
  Change `catch (_)` to `catch (e, st)` and log both the error and stack trace via
  the project's standard logger before setting `replayVerified = false`. Example:
  ```dart
  } catch (e, st) {
    // AUTO
    logger.warning('Ledger verify failed', e, st);
    replayVerified = false;
  }
  ```
  Identify the logger instance or logging pattern used elsewhere in this service and
  match it exactly.

---

### P1 — Bug 3: `integrityScore` is binary (0 or 100), not a real percentage

- **Action: REVIEW**
- **Finding:** `integrityScore` is typed as `int` and is set to `replayVerified ? 100 : 0`
  — making it a boolean disguised as a percentage. Any consumer of this field that
  treats it as a true integrity percentage (e.g., a dashboard gauge, a threshold
  alert, or a compliance export) will receive a meaningless binary value.
- **Why it matters:** The field name `integrityScore` implies a graduated measure.
  The `SovereignReportLedgerIntegrity` model already carries `hashVerified` (the
  boolean). Having `integrityScore` duplicate `hashVerified` as 0/100 adds no
  information while creating the false impression of a richer metric. If a consumer
  ever alerts at `integrityScore < 80`, it will never fire — the value can only be
  0 or 100.
- **Evidence:**
  - `lib/application/morning_sovereign_report_service.dart:1661–1665`
  ```dart
  ledgerIntegrity: SovereignReportLedgerIntegrity(
    totalEvents: nightEvents.length,
    hashVerified: replayVerified,
    integrityScore: replayVerified ? 100 : 0,   // ← binary, not a percentage
  ),
  ```
  - Field declaration at lines 22 and 27 (`final int integrityScore`).
- **Why REVIEW (not AUTO):** A real percentage requires a product decision about what
  to measure. Candidates include: ratio of events that passed individual hash checks,
  ratio of verified vs total events in the replay window, or a composite score from
  multiple verifier dimensions. Codex cannot determine the correct formula without
  Zaks specifying what "integrity percentage" means for this domain.
- **Suggested follow-up for Codex (after Zaks decision):**
  Once the formula is agreed, update the `generate` factory to compute the score from
  event-level data and pass it as a proper 0–100 integer. If no graduated metric is
  available from the current verifier, consider removing `integrityScore` and relying
  solely on `hashVerified` to avoid misleading consumers.

---

## Duplication

None identified within this targeted scope.

---

## Coverage Gaps

- No test currently exercises the `_partnerDispatchStatusFromName` wildcard arm
  (`_ => PartnerDispatchStatus.accepted`). A regression test for the `unknown` fix
  should be added alongside the enum change.
- No test verifies that a `ReplayConsistencyVerifier.verify` exception produces a log
  entry. The log call introduced by Bug 2's fix should be covered by a mock-logger test.
- `integrityScore = 0` path is not tested independently of `hashVerified = false`.
  Once the score formula is defined, a dedicated unit test for each score band should
  be added.

---

## Performance / Stability Notes

None identified in this targeted scope.

---

## Recommended Fix Order

1. **Bug 2 (silent catch)** — Lowest risk change, highest diagnostic value. Can be
   done immediately without a domain model change.
2. **Bug 1 (unknown default)** — Requires enum extension. Medium blast radius (exhaustive
   switches will require updating). Fix after Bug 2 is landed.
3. **Bug 3 (binary score)** — Blocked on a product decision. Raise with Zaks first,
   then implement once the formula is agreed.
