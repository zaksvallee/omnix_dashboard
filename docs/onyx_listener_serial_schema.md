# ONYX Listener Serial Schema

Last updated: 2026-03-13 (Africa/Johannesburg)

## Purpose

This document defines the canonical envelope for the deferred Falcon/FSK serial
listener path before live wire-protocol capture is available.

Current status:
- Bench/schema scaffold only
- Not a production cutover path
- Real wire-protocol validation is still required on hardware

## Canonical Envelope

Serial captures should normalize into:

```json
{
  "provider": "falcon_serial",
  "transport": "serial",
  "external_id": "falcon_serial-ACC-PTN-CODE-ZONE-<ts>",
  "raw_line": "1130 01 004 1234 0001 2026-03-13T08:15:00Z",
  "account_number": "1234",
  "partition": "01",
  "event_code": "130",
  "event_qualifier": "1",
  "zone": "004",
  "user_code": "0001",
  "site_id": "SITE-SANDTON",
  "client_id": "CLIENT-001",
  "region_id": "REGION-GAUTENG",
  "occurred_at_utc": "2026-03-13T08:15:00Z",
  "metadata": {
    "parse_mode": "tokenized",
    "token_count": 6
  }
}
```

## Bench Assumptions

Until a real Falcon/panel capture is available, the bench parser accepts:

1. Tokenized lines:
   - `<qualifier+event_code> <partition> <zone> <account> [user_code] [timestamp]`
2. JSON lines:
   - one JSON object per line using the canonical keys above

These assumptions are deliberately narrow so that real wire capture can replace
them cleanly instead of forcing support for speculative protocol variants.

## Initial Event Mapping

- `130` -> `BURGLARY_ALARM`
- `131` -> `PERIMETER_ALARM`
- `140` -> `GENERAL_ALARM`
- `301` -> `OPENING`
- `302` -> `CLOSING`
- other codes -> `LISTENER_EVENT`

## Bench Replay

Use:

```bash
./scripts/onyx_listener_serial_bench.sh \
  --input tmp/listener_serial_capture/sample.txt \
  --client-id CLIENT-001 \
  --region-id REGION-GAUTENG \
  --site-id SITE-SANDTON \
  --max-capture-signatures 2 \
  --max-fallback-timestamp-count 0 \
  --max-unknown-event-rate-percent 5
```

The script emits parsed envelopes to `tmp/listener_serial_bench/<timestamp>/parsed.json`.
The bench artifact now includes:
- `accepted`
- `rejected` with `line`, `line_number`, and `reason`
- `stats.accepted_count`
- `stats.rejected_count`
- `stats.ignored_count`
- `stats.reject_reason_counts`
- `stats.timestamp_source_counts`
- `stats.warning_counts`
- `stats.event_code_counts`
- `stats.qualifier_counts`
- `stats.parse_mode_counts`
- `stats.capture_signature_counts`
- `stats.unexpected_capture_signature_counts`
- `anomaly_gate.status`
- `anomaly_gate.thresholds`
- `anomaly_gate.observed`
- `anomaly_gate.failures`

Accepted events now record timestamp provenance in `metadata.timestamp_source`:
- `embedded_token`
- `embedded_json`
- `fallback_now`

When present, accepted events also record:
- `metadata.timestamp_token` for tokenized embedded timestamps
- `metadata.timestamp_field` for JSON timestamps (`occurred_at_utc` vs `timestamp`)
- `metadata.normalized_event_label`
- `metadata.risk_score`
- `metadata.normalization_status`
- `metadata.normalization_warning`
- `metadata.normalization_warnings`
- `metadata.capture_signature`

Capture signatures summarize the observed frame shape for profiling:
- parse mode (`tokenized` or `json_line`)
- token count when applicable
- timestamp source and timestamp field when applicable
- occupancy of partition, zone, user, and qualifier fields

The bench script can also enforce anomaly gates during capture profiling:
- `--max-capture-signatures`
- `--allow-capture-signature`
- `--max-unexpected-signatures`
- `--max-fallback-timestamp-count`
- `--max-unknown-event-rate-percent`

Those thresholds can be persisted in `tmp/listener_capture/listener_bench_baseline.json`
or passed explicitly with `--bench-baseline-json` to the pilot/field scripts.
CLI flags override values loaded from the baseline file.

To promote a reviewed field run back into the baseline:

```bash
./scripts/onyx_listener_bench_baseline_promote.sh \
  --source-json tmp/listener_field_validation/<timestamp>/validation_report.json \
  --baseline-json tmp/listener_capture/listener_bench_baseline.json
```

The promotion script:
- accepts `validation_report.json` or `serial_parsed.json`
- refuses `investigate_new_frame_shape` promotions unless `--force` is supplied
- can merge or replace signatures
- records `promotion_history` inside the baseline file

If any configured anomaly threshold is exceeded, the script still writes
`parsed.json` but exits with code `2` and records the failure details in
`anomaly_gate.failures`.

Current normalization warnings:
- `unknown_event_code`
- `nonstandard_event_qualifier`

Common reject reasons:
- `insufficient_tokens`
- `invalid_qualifier_code`
- `missing_account_number`
- `invalid_account_number`
- `invalid_partition`
- `invalid_zone`
- `invalid_json`
- `json_missing_timestamp`
- `json_missing_event_code`
- `json_missing_account_number`
- `json_invalid_numeric_fields`
- `json_invalid_partition`
- `json_invalid_zone`
- `json_invalid_qualifier`

## Parity Report

Once both paths are available, compare the serial bench output to the legacy
listener export:

```bash
./scripts/onyx_listener_parity_report.sh \
  --serial tmp/listener_serial_bench/<timestamp>/parsed.json \
  --legacy tmp/listener_legacy_export/accepted.json
```

The report emits:
- `report.md` alongside `report.json` for field review
- `status`
- `primary_issue_code`
- `fail_codes`
- `warning_codes`
- `matched_count`
- `unmatched_serial_count`
- `unmatched_legacy_count`
- `match_rate_percent`
- `max_skew_seconds_observed`
- `average_skew_seconds`
- `drift_reason_counts`
- `unmatched_serial_drifts`
- `unmatched_legacy_drifts`
- per-event skew in seconds for matched pairs
- `trend_report.json` and `trend_report.md` can be generated to compare one run against the prior run

Current hardening gate defaults:
- minimum match rate: `95%`
- maximum observed skew gate: optional override in readiness/pilot scripts
- zero unmatched serial and legacy events unless explicitly relaxed
- drift policy can be made reason-aware with `--allow-drift-reason` and `--max-drift-reason-count`

## Pilot Gate

Once `tmp/listener_capture/` is filled with real capture data:

```bash
./scripts/onyx_listener_pilot_gate.sh \
  --capture-dir tmp/listener_capture \
  --site-id SITE-SANDTON \
  --device-path /dev/ttyUSB0 \
  --legacy-source legacy_listener \
  --min-match-rate-percent 95 \
  --max-observed-skew-seconds 90 \
  --max-capture-signatures 2 \
  --max-fallback-timestamp-count 0 \
  --max-unknown-event-rate-percent 5 \
  --bench-baseline-json tmp/listener_capture/listener_bench_baseline.json \
  --allow-drift-reason zone_mismatch \
  --max-drift-reason-count zone_mismatch=2 \
  --compare-previous \
  --allow-match-rate-drop-percent 1 \
  --allow-max-skew-increase-seconds 5
```

Then generate the closeout:

```bash
./scripts/onyx_listener_signoff_generate.sh
```

If trend regression checking must be part of signoff:

```bash
./scripts/onyx_listener_signoff_generate.sh --require-trend-pass
```

To compare the latest parity run against the prior one:

```bash
./scripts/onyx_listener_parity_trend_check.sh
```

The pilot gate can also run this trend comparison inline and emit
`trend_report.json` plus `trend_report.md` into the pilot artifact directory.
It now also emits `parity_readiness_report.json` plus
`parity_readiness_report.md` in that same directory.
It also emits `pilot_gate_report.json` plus `pilot_gate_report.md` on both
pass and fail, so parity, parity readiness, and parity trend posture remain
auditable without relying on terminal output alone.
The pilot-gate terminal summary now also prints the parity report status,
parity primary issue code, parity-trend status, and parity-trend primary
regression code when those artifacts exist.

The parity-trend artifact also carries `primary_regression_code` plus
`regression_codes`, so downstream gates can classify parity regressions
without parsing prose summaries.

To compare the latest field-validation bundle against the prior one:

```bash
./scripts/onyx_listener_validation_trend_check.sh \
  --allow-baseline-age-increase-days 7
```

This emits `validation_trend_report.json` plus `validation_trend_report.md`
next to the current `validation_report.json`, and it fails when:
- `overall_status` regresses
- any validation gate flips from `true` to `false`
- `baseline_review` regresses from `hold_baseline` to `promote_baseline` or `investigate_new_frame_shape`
- `baseline_health` regresses from `fresh` to a weaker category
- `baseline_health.age_days` increases beyond the allowed threshold

The validation-trend artifact also carries `primary_regression_code` plus
`regression_codes`, so downstream gates can classify validation regressions
without parsing prose summaries.

To collapse the latest validation/trend posture into one cutover decision:

```bash
./scripts/onyx_listener_cutover_decision.sh \
  --require-real-artifacts
```

This emits `cutover_decision.json` plus `cutover_decision.md` with:
- `decision = GO|HOLD|BLOCK`
- `primary_blocking_code` and `primary_hold_code`
- `blocking_codes`
- `hold_codes`
- `blocking_reasons`
- `hold_reasons`
- resolved validation/parity/trend artifact references

When parity or trend paths are not passed explicitly, standalone cutover
decision generation now auto-resolves:
- `files.parity_report_json`
- `files.trend_report_json`
- `validation_trend_report.json`

from the validation bundle before falling back to same-directory defaults.

Decision policy:
- `GO`
  all hard validation gates pass, the bundle is non-mock when required, baseline review is `hold_baseline`, baseline health is not degraded, and any supplied parity/validation trend artifacts are `PASS`
- `HOLD`
  software validation passed, but cutover should wait for baseline promotion/freshness or missing trend artifacts
- `BLOCK`
  validation failed, hard gates regressed, investigation is required, or a supplied trend artifact failed

To compare the latest cutover decision against the prior one:

```bash
./scripts/onyx_listener_cutover_trend_check.sh
```

This emits `cutover_trend_report.json` plus `cutover_trend_report.md` and
fails when:
- `decision` regresses from `GO -> HOLD` or `HOLD -> BLOCK`
- hold-reason count increases beyond the allowed threshold
- blocking-reason count increases beyond the allowed threshold

The cutover-trend artifact also carries `primary_regression_code` plus
`regression_codes`, so downstream gates can classify cutover regressions
without parsing prose summaries.

Cutover decision consumers now also verify that the decision artifact's copied
`statuses.*`, `gates.*`, `parity_summary`, and primary code fields still match
the validation/parity/trend artifacts it references. That prevents a stale or
hand-edited `cutover_decision.json` from satisfying readiness, cutover-trend,
or release checks on path integrity alone.

Release-gate consumers now do the same for `release_gate.json`: copied
`statuses.*`, `primary_*_code`, and result/code-shape fields must still match
the validation, readiness, cutover, cutover-trend, and signoff artifacts they
reference. That prevents a stale or hand-edited `release_gate.json` from
satisfying readiness or release-trend checks on referenced-path integrity
alone.

Standalone cutover and release consumers now also treat the staged
`pilot_gate_report.json` inside a validation bundle as structured evidence
rather than a checksummed blob. If the pilot gate's copied bench/parity/parity
readiness/parity trend statuses no longer match the artifacts it references,
cutover/release posture and their trend checks now fail directly.

Listener signoff now also records the readiness artifact it actually used, plus
the copied readiness status and failure code. Release posture and release-trend
checks verify those readiness fields the same way they already verify signoff
trend and cutover fields.
Release posture and release-trend also reject contradictory top-level signoff
state, such as `status = PASS` with a non-empty `failure_code` or
`status = FAIL` without one.
They also verify the signoff mock-artifact policy against the referenced
validation bundle, so a tampered signoff report cannot claim mock artifacts
were disallowed while still pointing at a mock field bundle.
Release posture also rejects mixed-bundle signoff, so a signoff report cannot
quietly point at a different validation, readiness, or cutover artifact than
the release gate that is trying to consume it.
That alignment now also covers the validation bundle's staged parity report
and parity trend, so a signoff cannot quietly borrow a parity chain from a
different listener run.
It also covers the resolved validation-trend artifact, so signoff cannot
quietly borrow a different validation-trend report while still citing the same
validation bundle.

Cutover and release trend comparisons now prefer stable machine-readable
`hold_codes`, `blocking_codes`, and `fail_codes` when present, falling back to
the older prose reason arrays only for legacy artifacts. That prevents
markdown or wording-only changes from registering as false regressions.

To collapse validation, cutover posture, and signoff presence into one final
release gate:

```bash
./scripts/onyx_listener_release_gate.sh \
  --require-real-artifacts
```

This emits `release_gate.json` plus `release_gate.md` with:
- `result = PASS|HOLD|FAIL`
- `primary_fail_code` and `primary_hold_code`
- `fail_codes`
- `hold_codes`
- `fail_reasons`
- `hold_reasons`
- resolved validation/readiness/cutover/signoff references

Standalone release-gate discovery now only auto-selects signoff artifacts whose
filenames contain `signoff`, so `readiness_report.md`, `release_trend_report.md`,
and other audited markdown/json artifacts cannot be misclassified as signoff.

When a readiness artifact is present, the release gate now also carries
`statuses.readiness_failure_code` forward so downstream tooling can distinguish
why readiness failed without parsing prose.

Listener signoff generation now also emits a sibling `signoff_report.json`
next to the markdown closeout, and the release gate consumes that structured
signoff status when present. The signoff report now persists on both pass and
fail and carries `failure_code`, so downstream tooling does not need to parse
terminal output when signoff generation is blocked.
When signoff is generated through the one-command field gate, it now uses the
staged parity report and staged parity trend from the field-validation bundle
rather than the pilot subdirectory copies, so release posture sees one
consistent parity chain.

Release posture now treats a present `signoff_report.json` as sufficient
evidence of signoff presence. Missing markdown alone no longer forces a hold
when the audited signoff report exists and passes.

Standalone signoff generation now also auto-resolves:
- `validation_report.json`
- `validation_trend_report.json`
- `cutover_decision.json`
- `cutover_trend_report.json`

from the parity artifact directory when those files are colocated in a staged
field-validation bundle, before falling back to the older parent-directory
layout.

To compare release posture across listener runs:

```bash
./scripts/onyx_listener_release_trend_check.sh
```

This emits `release_trend_report.json` plus `release_trend_report.md` and
fails when:
- release `result` regresses from `PASS -> HOLD` or `HOLD -> FAIL`
- hold-reason count increases beyond the allowed threshold
- fail-reason count increases beyond the allowed threshold

The release-trend artifact also carries `primary_regression_code` plus
`regression_codes`, so downstream gates can classify release regressions
without parsing markdown or prose summaries.

To create a self-contained field-validation bundle from a real capture pack:

```bash
./scripts/onyx_listener_field_validation.sh \
  --capture-dir tmp/listener_capture \
  --site-id SITE-SANDTON \
  --device-path /dev/ttyUSB0 \
  --legacy-source legacy_listener \
  --bench-baseline-json tmp/listener_capture/listener_bench_baseline.json \
  --max-capture-signatures 2 \
  --max-fallback-timestamp-count 0 \
  --max-unknown-event-rate-percent 5 \
  --compare-previous \
  --allow-match-rate-drop-percent 1 \
  --allow-max-skew-increase-seconds 5
```

To confirm the latest listener field-validation bundle is signoff-ready:

```bash
./scripts/onyx_listener_pilot_readiness_check.sh \
  --json-out tmp/listener_field_validation/<timestamp>/readiness_report.json \
  --require-trend-pass \
  --require-validation-trend-pass \
  --require-cutover-go \
  --require-cutover-trend-pass \
  --require-baseline-history \
  --max-baseline-age-days 30
```

This writes `readiness_report.json` plus `readiness_report.md`. The readiness
artifact is emitted on both passing and failing runs once the validation bundle
has been resolved, so downstream tooling can audit failed readiness checks
without relying on terminal output alone.

On failure, `readiness_report.json` now also includes a machine-readable
`failure_code` so downstream gates do not need to parse the human summary.

The parity readiness gate follows the same pattern and emits
`parity_readiness_report.json` plus `parity_readiness_report.md` on both pass
and fail, with a machine-readable `failure_code`.

The standalone parity bundle now also records
`checksums.report_markdown_sha256`, and parity readiness verifies the copied
parity markdown summary alongside the copied serial and legacy inputs. A parity
artifact with a missing or mutated `report.md` is now treated as corrupted
evidence, not just incomplete documentation.

The validation bundle stages `pilot_gate_report.json` plus
`pilot_gate_report.md` when present, and records both paths plus checksums
under `files.*` and `checksums.*`. Listener readiness verifies those staged
checksums alongside the rest of the validation evidence bundle.

It now also stages `parity_readiness_report.json` plus
`parity_readiness_report.md` from the standalone pilot artifact when present,
so the field-validation bundle preserves the full parity-readiness evidence
chain instead of only the top-level validation gate result.

To drive the full listener field flow in one command:

```bash
./scripts/onyx_listener_field_gate.sh \
  --capture-dir tmp/listener_capture \
  --site-id SITE-SANDTON \
  --device-path /dev/ttyUSB0 \
  --legacy-source legacy_listener \
  --bench-baseline-json tmp/listener_capture/listener_bench_baseline.json \
  --max-capture-signatures 2 \
  --max-fallback-timestamp-count 0 \
  --max-unknown-event-rate-percent 5 \
  --compare-previous \
  --compare-previous-validation \
  --compare-previous-release \
  --allow-validation-baseline-age-increase-days 7 \
  --require-release-gate-pass \
  --require-release-trend-pass \
  --generate-signoff
```

When `--generate-signoff` is used without `--signoff-out`, the field gate now
writes:
- `listener_pilot_signoff.md`
- `listener_pilot_signoff.json`

directly into the field artifact directory, and the release gate consumes both
artifacts explicitly instead of relying on loose markdown discovery.

For local tooling checks without real hardware:

```bash
./scripts/onyx_listener_mock_validation_artifacts.sh
```

These mock artifacts are valid for local gate verification only and should be
rejected for real pilot signoff with `--require-real-artifacts`.

When `--compare-previous-validation` is enabled, the field gate also emits:
- `pilot_gate_report.json`
- `pilot_gate_report.md`
- `parity_readiness_report.json`
- `parity_readiness_report.md`
- `validation_trend_report.json`
- `validation_trend_report.md`
- `cutover_decision.json`
- `cutover_decision.md`
- `cutover_trend_report.json`
- `cutover_trend_report.md`
- `readiness_report.json`
- `readiness_report.md`
- `signoff_report.json`
- `release_gate.json`
- `release_gate.md`
- `release_trend_report.json`
- `release_trend_report.md`

The field-gate terminal summary now prints validation-trend status and summary
alongside the baseline review, baseline health, cutover decision, cutover trend, release-gate result, and release-trend status.

When `--require-release-gate-pass` is enabled, the field gate will fail unless
`release_gate.json` resolves to `result = PASS`. A `HOLD` release posture is
still emitted as an artifact, but it is treated as a blocking outcome for that
invocation.

When `--require-release-trend-pass` is enabled, the field gate will fail unless
`release_trend_report.json` resolves to `status = PASS`.

Readiness can also enforce release posture explicitly:
- `--release-gate-json <path>`
- `--require-release-gate-pass`
- `--release-trend-report-json <path>`
- `--require-release-trend-pass`

When enabled, readiness verifies that the release gate resolves to `PASS` and
that the release-trend artifact resolves to `PASS`.

Readiness now also verifies the referenced evidence chain inside those
aggregated artifacts instead of trusting only their top-level status:
- `cutover_decision.json` must still point at existing staged validation,
  parity, parity-trend, and validation-trend files when those paths are set.
- `release_gate.json` must still point at existing staged validation,
  readiness, cutover, cutover-trend, signoff markdown, and signoff report
  files when those paths are set.
- `cutover_trend_report.json` must still point at current and previous
  cutover-decision artifacts whose own referenced evidence files still exist.
- `release_trend_report.json` must still point at current and previous
  release-gate artifacts whose own referenced evidence files still exist.
- the staged `pilot_gate_report.json` must still point at the staged serial,
  parity, parity-readiness, and optional parity-trend artifacts it summarizes,
  and its recorded status/code fields must still match those underlying
  artifacts.
- later release consumers also verify that `readiness_report.json` still
  matches the validation/trend/cutover artifacts and requirement flags it
  resolved when the readiness report was written.
- readiness and validation-trend also verify that the top-level
  `baseline_review`, `baseline_health`, gate booleans, and primary code fields
  inside `validation_report.json` still match the staged JSON artifacts and
  status arrays they summarize.
- standalone cutover/release consumers and cutover/release trend artifacts now
  enforce that same validation-bundle summary consistency, so misleading
  top-level validation summaries cannot survive outside the readiness path.

Standalone release posture now enforces the same rule at artifact generation
time for the evidence it consumes directly:
- a staged `cutover_decision.json` cannot contribute to a clean release result
  if its referenced validation, parity, parity-trend, or validation-trend
  files are missing.
- a staged `signoff_report.json` cannot contribute to a clean release result
  if its referenced parity, trend, validation, validation-trend, cutover, or
  cutover-trend files are missing, or if its recorded status fields and
  enforced requirement flags do not match those referenced artifacts.

Standalone cutover and signoff generation now enforce the same parity-side
evidence-chain integrity:
- `cutover_decision.json` cannot resolve to `GO` if the staged parity report
  points at missing copied serial/legacy inputs, missing parity markdown,
  checksum-mismatched copied parity files, or if the staged parity trend
  points at missing current/previous parity reports or at current/previous
  parity reports whose own copied inputs or markdown summaries are missing or
  checksum-mismatched.
- `signoff_report.json` cannot resolve to `PASS` if the supplied parity report
  or parity trend points at missing copied inputs, missing markdown
  summaries, or checksum-mismatched copied parity files, even when
  validation/readiness posture is otherwise passing.

Standalone release posture now also walks one level deeper through staged
cutover-trend evidence:
- `release_gate.json` cannot resolve cleanly from a `PASS` cutover-trend if
  that trend points at current or previous cutover decisions whose referenced
  validation, parity, parity-trend, or validation-trend files are missing.

The trend generators themselves now also fail early on hollow current or
previous inputs instead of deferring that detection to downstream gates:
- `trend_report.json` fails if the current or previous parity report points at
  missing copied serial/legacy inputs, missing parity markdown, or checksum
  mismatches between those copied files and the parity report metadata.
- `validation_trend_report.json` fails if the current or previous validation
  bundle points at missing staged evidence files, checksum-mismatched staged
  evidence files, missing staged metadata paths, missing staged checksum
  metadata, or a missing validation artifact directory.
- `validation_trend_report.json` also fails if the current or previous staged
  `pilot_gate_report.json` no longer matches the staged serial/parity/parity-
  readiness/parity-trend artifacts it summarizes.
- `cutover_trend_report.json` fails if the current or previous cutover
  decision or any nested validation/parity/trend evidence it references is
  hollow, including checksum-mismatched copied parity files or
  checksum-mismatched staged validation files.
- `release_trend_report.json` fails if the current or previous release gate
  or any nested readiness/cutover/signoff evidence it references is hollow,
  including checksum-mismatched copied parity files or checksum-mismatched
  staged validation files inside those nested chains.

Readiness and signoff can also enforce validation-trend pass explicitly:
- `--validation-trend-report-json <path>`
- `--require-validation-trend-pass`

When enabled, readiness verifies that the validation-trend artifact exists,
references real current/previous validation reports, and has `status = PASS`.

Readiness and signoff can also enforce cutover posture explicitly:
- `--cutover-decision-json <path>`
- `--require-cutover-go`
- `--cutover-trend-report-json <path>`
- `--require-cutover-trend-pass`

When enabled, readiness verifies that the cutover decision resolves to `GO`
and that the cutover trend artifact resolves to `PASS`.

Field validation and readiness now also enforce the serial bench anomaly gate:
- `gates.bench_anomaly_gate_passed`
- `files.serial_parsed_json`
- `files.bench_baseline_json`
- `files.baseline_review_json`
- `files.baseline_health_json`
- `checksums.serial_parsed_json_sha256`
- `checksums.bench_baseline_json_sha256`
- `checksums.baseline_review_json_sha256`
- `checksums.baseline_health_json_sha256`

The top-level validation bundle also carries:
- `primary_failure_code` and `primary_warning_code`
- `failure_codes`
- `warning_codes`

so downstream automation can classify validation posture without parsing the
human summary or gate messages.

Field validation also emits `baseline_review` with:
- `status`
- `recommendation`
- `summary`
- `observed_signatures`
- `baseline_signatures`
- `effective_allowed_signatures`
- `new_observed_signatures`
- `missing_baseline_signatures`

Recommendation meanings:
- `hold_baseline`
- `promote_baseline`
- `investigate_new_frame_shape`

Field validation also emits advisory `baseline_health` with:
- `status`
- `category`
- `summary`
- `last_promoted_at_utc`
- `age_days`

Baseline health categories:
- `fresh`
- `stale`
- `missing_history`
- `invalid_timestamp`
- `missing_baseline`

Readiness can also doctor the persisted baseline:
- `--require-baseline-history`
- `--max-baseline-age-days <days>`

Under `--require-real-artifacts`, readiness now automatically requires baseline
history. Use `--max-baseline-age-days` to fail on stale promoted baselines.

## Non-Goals

- No transmit/control path
- No panel writeback
- No production cutover decision
- No claim that the tokenized parser matches the final Falcon wire protocol
