#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INPUT_FILE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
SITE_ID="SITE-SANDTON"
OUT_FILE=""
MAX_CAPTURE_SIGNATURES=""
MAX_UNEXPECTED_SIGNATURES=""
MAX_FALLBACK_TIMESTAMP_COUNT=""
MAX_UNKNOWN_EVENT_RATE_PERCENT=""
ALLOW_CAPTURE_SIGNATURES=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_serial_bench.sh --input <path> [--client-id <id>] [--region-id <id>] [--site-id <id>] [--out <path>]
    [--max-capture-signatures <count>]
    [--allow-capture-signature <signature>]
    [--max-unexpected-signatures <count>]
    [--max-fallback-timestamp-count <count>]
    [--max-unknown-event-rate-percent <percent>]

Purpose:
  Replay captured Falcon/listener serial lines through the ONYX serial envelope
  normalizer and emit parsed JSON for bench validation before hardware cutover.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_FILE="${2:-}"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="${2:-}"
      shift 2
      ;;
    --region-id)
      REGION_ID="${2:-}"
      shift 2
      ;;
    --site-id)
      SITE_ID="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --max-capture-signatures)
      MAX_CAPTURE_SIGNATURES="${2:-}"
      shift 2
      ;;
    --allow-capture-signature)
      ALLOW_CAPTURE_SIGNATURES+=("${2:-}")
      shift 2
      ;;
    --max-unexpected-signatures)
      MAX_UNEXPECTED_SIGNATURES="${2:-}"
      shift 2
      ;;
    --max-fallback-timestamp-count)
      MAX_FALLBACK_TIMESTAMP_COUNT="${2:-}"
      shift 2
      ;;
    --max-unknown-event-rate-percent)
      MAX_UNKNOWN_EVENT_RATE_PERCENT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "FAIL: --input must point to an existing serial capture file."
  exit 1
fi

if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_FILE="tmp/listener_serial_bench/$stamp/parsed.json"
fi
mkdir -p "$(dirname "$OUT_FILE")"

ALLOWED_CAPTURE_SIGNATURES_SERIALIZED=""
if [[ ${#ALLOW_CAPTURE_SIGNATURES[@]} -gt 0 ]]; then
  ALLOWED_CAPTURE_SIGNATURES_SERIALIZED="$(printf '%s\n' "${ALLOW_CAPTURE_SIGNATURES[@]}")"
fi

LISTENER_MAX_CAPTURE_SIGNATURES="$MAX_CAPTURE_SIGNATURES" \
LISTENER_MAX_UNEXPECTED_SIGNATURES="$MAX_UNEXPECTED_SIGNATURES" \
LISTENER_MAX_FALLBACK_TIMESTAMP_COUNT="$MAX_FALLBACK_TIMESTAMP_COUNT" \
LISTENER_MAX_UNKNOWN_EVENT_RATE_PERCENT="$MAX_UNKNOWN_EVENT_RATE_PERCENT" \
LISTENER_ALLOWED_CAPTURE_SIGNATURES="$ALLOWED_CAPTURE_SIGNATURES_SERIALIZED" \
python3 - "$INPUT_FILE" "$CLIENT_ID" "$REGION_ID" "$SITE_ID" "$OUT_FILE" <<'PY'
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

input_path = Path(sys.argv[1])
client_id = sys.argv[2]
region_id = sys.argv[3]
site_id = sys.argv[4]
out_file = Path(sys.argv[5])

accepted = []
rejected = []
ignored_count = 0
reject_reason_counts = {}
timestamp_source_counts = {}
warning_counts = {}
event_code_counts = {}
qualifier_counts = {}
parse_mode_counts = {}
capture_signature_counts = {}
unexpected_capture_signature_counts = {}
gate_failures = []

max_capture_signatures_raw = os.environ.get("LISTENER_MAX_CAPTURE_SIGNATURES", "").strip()
max_unexpected_signatures_raw = os.environ.get("LISTENER_MAX_UNEXPECTED_SIGNATURES", "").strip()
max_fallback_timestamp_count_raw = os.environ.get("LISTENER_MAX_FALLBACK_TIMESTAMP_COUNT", "").strip()
max_unknown_event_rate_percent_raw = os.environ.get("LISTENER_MAX_UNKNOWN_EVENT_RATE_PERCENT", "").strip()
allowed_capture_signatures = [
    line.strip()
    for line in os.environ.get("LISTENER_ALLOWED_CAPTURE_SIGNATURES", "").splitlines()
    if line.strip()
]
allowed_capture_signature_set = set(allowed_capture_signatures)

def parse_optional_int(raw: str, label: str):
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError as exc:
        raise SystemExit(f"FAIL: {label} must be an integer.") from exc

def parse_optional_float(raw: str, label: str):
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError as exc:
        raise SystemExit(f"FAIL: {label} must be numeric.") from exc

max_capture_signatures = parse_optional_int(
    max_capture_signatures_raw,
    "--max-capture-signatures",
)
max_unexpected_signatures = parse_optional_int(
    max_unexpected_signatures_raw,
    "--max-unexpected-signatures",
)
max_fallback_timestamp_count = parse_optional_int(
    max_fallback_timestamp_count_raw,
    "--max-fallback-timestamp-count",
)
max_unknown_event_rate_percent = parse_optional_float(
    max_unknown_event_rate_percent_raw,
    "--max-unknown-event-rate-percent",
)

def add_reject(raw: str, line_number: int, reason: str):
    rejected.append(
        {
            "line": raw,
            "line_number": line_number,
            "reason": reason,
        }
    )
    reject_reason_counts[reason] = reject_reason_counts.get(reason, 0) + 1

def track_timestamp_source(source: str):
    timestamp_source_counts[source] = timestamp_source_counts.get(source, 0) + 1

def track_warning(reason: str):
    warning_counts[reason] = warning_counts.get(reason, 0) + 1

def track_value(counts: dict, value: str):
    value = str(value).strip()
    if not value:
        return
    counts[value] = counts.get(value, 0) + 1

def capture_signature(
    *,
    parse_mode: str,
    timestamp_source: str,
    partition: str,
    zone: str,
    user_code: str,
    event_qualifier: str,
    token_count=None,
    timestamp_field: str = "",
):
    segments = [parse_mode]
    if token_count is not None:
        segments.append(f"tokens={token_count}")
    segments.append(f"timestamp={str(timestamp_source).strip() or 'unknown'}")
    timestamp_field = str(timestamp_field).strip()
    if timestamp_field:
        segments.append(f"timestamp_field={timestamp_field}")
    segments.append(f"partition={'present' if str(partition).strip() else 'absent'}")
    segments.append(f"zone={'present' if str(zone).strip() else 'absent'}")
    segments.append(f"user={'present' if str(user_code).strip() else 'absent'}")
    segments.append(f"qualifier={'present' if str(event_qualifier).strip() else 'absent'}")
    return "|".join(segments)

def qualifier_warnings(qualifier: str):
    qualifier = qualifier.strip()
    if not qualifier or qualifier in {"1", "3", "6"}:
        return []
    return ["nonstandard_event_qualifier"]

def event_info(event_code: str):
    event_code = event_code.strip()
    if event_code == "130":
        return ("BURGLARY_ALARM", 96, [])
    if event_code == "131":
        return ("PERIMETER_ALARM", 91, [])
    if event_code == "140":
        return ("GENERAL_ALARM", 88, [])
    if event_code == "301":
        return ("OPENING", 35, [])
    if event_code == "302":
        return ("CLOSING", 35, [])
    return ("LISTENER_EVENT", 55, ["unknown_event_code"])

def digits_only(value: str) -> bool:
    return bool(re.fullmatch(r"\d+", value.strip()))

def ts_from_tokens(tokens):
    for token in reversed(tokens):
        try:
            return (
                datetime.fromisoformat(token.replace("Z", "+00:00"))
                .astimezone(timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "embedded_token",
                token,
            )
        except Exception:
            continue
    return (
        datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "fallback_now",
        "",
    )

for index, raw in enumerate(input_path.read_text(encoding="utf-8").splitlines(), start=1):
    line = raw.strip()
    if not line:
      ignored_count += 1
      continue
    if line.startswith("#"):
      ignored_count += 1
      continue
    envelope = None
    reject_reason = None
    if line.startswith("{"):
        try:
            payload = json.loads(line)
            if isinstance(payload, dict):
                occurred = payload.get("occurred_at_utc") or payload.get("timestamp")
                event_code = str(payload.get("event_code", payload.get("code", ""))).strip()
                account_number = str(payload.get("account_number", payload.get("account", ""))).strip()
                partition = str(payload.get("partition", "")).strip()
                zone = str(payload.get("zone", "")).strip()
                event_qualifier = str(payload.get("event_qualifier", payload.get("qualifier", ""))).strip()
                if not occurred:
                    reject_reason = "json_missing_timestamp"
                elif not event_code:
                    reject_reason = "json_missing_event_code"
                elif not account_number:
                    reject_reason = "json_missing_account_number"
                elif not digits_only(event_code) or not digits_only(account_number):
                    reject_reason = "json_invalid_numeric_fields"
                elif partition and not digits_only(partition):
                    reject_reason = "json_invalid_partition"
                elif zone and not digits_only(zone):
                    reject_reason = "json_invalid_zone"
                elif event_qualifier and not digits_only(event_qualifier):
                    reject_reason = "json_invalid_qualifier"
                else:
                    normalized_label, risk_score, normalization_warnings = event_info(event_code)
                    normalization_warnings = [
                        *normalization_warnings,
                        *qualifier_warnings(event_qualifier),
                    ]
                    timestamp_field = "occurred_at_utc" if payload.get("occurred_at_utc") is not None else "timestamp"
                    user_code = str(payload.get("user_code", payload.get("user", ""))).strip()
                    envelope = {
                        "provider": payload.get("provider", "falcon_serial"),
                        "transport": payload.get("transport", "serial"),
                        "external_id": payload.get("external_id") or payload.get("id") or f"falcon_serial-{occurred}",
                        "raw_line": raw,
                        "account_number": account_number,
                        "partition": partition,
                        "event_code": event_code,
                        "event_qualifier": event_qualifier,
                        "zone": zone,
                        "user_code": user_code,
                        "site_id": payload.get("site_id", site_id),
                        "client_id": payload.get("client_id", client_id),
                        "region_id": payload.get("region_id", region_id),
                        "occurred_at_utc": occurred,
                        "metadata": {
                            **payload.get("metadata", {}),
                            "parse_mode": "json_line",
                            "timestamp_source": "embedded_json",
                            "timestamp_field": timestamp_field,
                            "capture_signature": capture_signature(
                                parse_mode="json_line",
                                timestamp_source="embedded_json",
                                timestamp_field=timestamp_field,
                                partition=partition,
                                zone=zone,
                                user_code=user_code,
                                event_qualifier=event_qualifier,
                            ),
                            "normalized_event_label": normalized_label,
                            "risk_score": risk_score,
                            "normalization_status": "warning" if normalization_warnings else "known_event_code",
                            **({"normalization_warning": normalization_warnings[0]} if normalization_warnings else {}),
                            **({"normalization_warnings": normalization_warnings} if normalization_warnings else {}),
                        },
                    }
            else:
                reject_reason = "json_not_object"
        except Exception:
            reject_reason = "invalid_json"
    if envelope is None:
        tokens = re.split(r"\s+", line)
        if reject_reason is None and len(tokens) < 4:
            reject_reason = "insufficient_tokens"
        if reject_reason is None and len(tokens[0]) < 4:
            reject_reason = "invalid_qualifier_code"
        if reject_reason is None and len(tokens) >= 4 and len(tokens[0]) >= 4:
            qualifier_code = tokens[0]
            qualifier = qualifier_code[0]
            event_code = qualifier_code[1:]
            partition = tokens[1]
            zone = tokens[2]
            account = tokens[3]
            if not digits_only(qualifier) or not digits_only(event_code):
                reject_reason = "invalid_qualifier_code"
            elif not account.strip():
                reject_reason = "missing_account_number"
            elif not digits_only(account):
                reject_reason = "invalid_account_number"
            elif partition.strip() and not digits_only(partition):
                reject_reason = "invalid_partition"
            elif zone.strip() and not digits_only(zone):
                reject_reason = "invalid_zone"
            else:
                normalized_label, risk_score, normalization_warnings = event_info(event_code)
                normalization_warnings = [
                    *normalization_warnings,
                    *qualifier_warnings(qualifier),
                ]
                occurred_at_utc, timestamp_source, timestamp_token = ts_from_tokens(tokens)
                envelope = {
                    "provider": "falcon_serial",
                    "transport": "serial",
                    "external_id": f"falcon_serial-{tokens[3]}-{tokens[1]}-{qualifier_code[1:]}-{tokens[2]}",
                    "raw_line": raw,
                    "account_number": tokens[3],
                    "partition": tokens[1],
                    "event_code": qualifier_code[1:],
                    "event_qualifier": qualifier_code[0],
                    "zone": tokens[2],
                    "user_code": tokens[4] if len(tokens) > 4 else "",
                    "site_id": site_id,
                    "client_id": client_id,
                    "region_id": region_id,
                    "occurred_at_utc": occurred_at_utc,
                    "metadata": {
                        "parse_mode": "tokenized",
                        "token_count": len(tokens),
                        "timestamp_source": timestamp_source,
                        "capture_signature": capture_signature(
                            parse_mode="tokenized",
                            token_count=len(tokens),
                            timestamp_source=timestamp_source,
                            partition=partition,
                            zone=zone,
                            user_code=tokens[4] if len(tokens) > 4 else "",
                            event_qualifier=qualifier,
                        ),
                        "normalized_event_label": normalized_label,
                        "risk_score": risk_score,
                        "normalization_status": "warning" if normalization_warnings else "known_event_code",
                        **({"normalization_warning": normalization_warnings[0]} if normalization_warnings else {}),
                        **({"normalization_warnings": normalization_warnings} if normalization_warnings else {}),
                        **({"timestamp_token": timestamp_token} if timestamp_token else {}),
                    },
                }
    if envelope is None:
        add_reject(raw, index, reject_reason or "unknown_reject_reason")
    else:
        accepted.append(envelope)
        metadata = envelope.get("metadata", {})
        track_value(event_code_counts, envelope.get("event_code", ""))
        track_value(qualifier_counts, envelope.get("event_qualifier", ""))
        track_value(parse_mode_counts, metadata.get("parse_mode", ""))
        track_value(capture_signature_counts, metadata.get("capture_signature", ""))
        track_timestamp_source(str(metadata.get("timestamp_source", "unknown")))
        warnings = metadata.get("normalization_warnings", [])
        if isinstance(warnings, list):
            for warning in warnings:
                warning_text = str(warning).strip()
                if warning_text:
                    track_warning(warning_text)
        else:
            warning = str(metadata.get("normalization_warning", "")).strip()
            if warning:
                track_warning(warning)

for signature, count in capture_signature_counts.items():
    if allowed_capture_signature_set and signature not in allowed_capture_signature_set:
        unexpected_capture_signature_counts[signature] = count

accepted_count = len(accepted)
observed_signature_count = len(capture_signature_counts)
unexpected_signature_total = sum(unexpected_capture_signature_counts.values())
fallback_timestamp_count = timestamp_source_counts.get("fallback_now", 0)
unknown_event_count = warning_counts.get("unknown_event_code", 0)
unknown_event_rate_percent = round(
    (unknown_event_count / accepted_count * 100.0) if accepted_count else 0.0,
    2,
)

if max_capture_signatures is not None and observed_signature_count > max_capture_signatures:
    gate_failures.append(
        {
            "type": "capture_signature_count_exceeded",
            "observed": observed_signature_count,
            "threshold": max_capture_signatures,
        }
    )
if max_unexpected_signatures is not None and unexpected_signature_total > max_unexpected_signatures:
    gate_failures.append(
        {
            "type": "unexpected_capture_signature_count_exceeded",
            "observed": unexpected_signature_total,
            "threshold": max_unexpected_signatures,
            "unexpected_capture_signature_counts": unexpected_capture_signature_counts,
        }
    )
if max_fallback_timestamp_count is not None and fallback_timestamp_count > max_fallback_timestamp_count:
    gate_failures.append(
        {
            "type": "fallback_timestamp_count_exceeded",
            "observed": fallback_timestamp_count,
            "threshold": max_fallback_timestamp_count,
        }
    )
if (
    max_unknown_event_rate_percent is not None
    and unknown_event_rate_percent > max_unknown_event_rate_percent
):
    gate_failures.append(
        {
            "type": "unknown_event_rate_exceeded",
            "observed_percent": unknown_event_rate_percent,
            "observed_count": unknown_event_count,
            "accepted_count": accepted_count,
            "threshold_percent": max_unknown_event_rate_percent,
        }
    )

payload = {
    "accepted": accepted,
    "rejected": rejected,
    "stats": {
        "accepted_count": len(accepted),
        "rejected_count": len(rejected),
        "ignored_count": ignored_count,
        "reject_reason_counts": reject_reason_counts,
        "timestamp_source_counts": timestamp_source_counts,
        "warning_counts": warning_counts,
        "event_code_counts": event_code_counts,
        "qualifier_counts": qualifier_counts,
        "parse_mode_counts": parse_mode_counts,
        "capture_signature_counts": capture_signature_counts,
        "unexpected_capture_signature_counts": unexpected_capture_signature_counts,
    },
    "anomaly_gate": {
        "status": "FAIL" if gate_failures else "PASS",
        "thresholds": {
            "max_capture_signatures": max_capture_signatures,
            "allowed_capture_signatures": allowed_capture_signatures,
            "max_unexpected_signatures": max_unexpected_signatures,
            "max_fallback_timestamp_count": max_fallback_timestamp_count,
            "max_unknown_event_rate_percent": max_unknown_event_rate_percent,
        },
        "observed": {
            "capture_signature_count": observed_signature_count,
            "unexpected_signature_total": unexpected_signature_total,
            "fallback_timestamp_count": fallback_timestamp_count,
            "unknown_event_count": unknown_event_count,
            "unknown_event_rate_percent": unknown_event_rate_percent,
        },
        "failures": gate_failures,
    },
}
out_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")
status_prefix = "FAIL" if gate_failures else "PASS"
print(
    f"{status_prefix}: Parsed"
    f" {len(accepted)} serial envelope(s);"
    f" rejected {len(rejected)};"
    f" ignored {ignored_count}."
)
if reject_reason_counts:
    print(f"Reject reasons: {json.dumps(reject_reason_counts, sort_keys=True)}")
if timestamp_source_counts:
    print(f"Timestamp sources: {json.dumps(timestamp_source_counts, sort_keys=True)}")
if warning_counts:
    print(f"Warnings: {json.dumps(warning_counts, sort_keys=True)}")
if event_code_counts:
    print(f"Observed event codes: {json.dumps(event_code_counts, sort_keys=True)}")
if qualifier_counts:
    print(f"Observed qualifiers: {json.dumps(qualifier_counts, sort_keys=True)}")
if parse_mode_counts:
    print(f"Parse modes: {json.dumps(parse_mode_counts, sort_keys=True)}")
if capture_signature_counts:
    print(f"Capture signatures: {json.dumps(capture_signature_counts, sort_keys=True)}")
if unexpected_capture_signature_counts:
    print(
        "Unexpected capture signatures:"
        f" {json.dumps(unexpected_capture_signature_counts, sort_keys=True)}"
    )
if gate_failures:
    print(f"Anomaly gate failures: {json.dumps(gate_failures, sort_keys=True)}")
print(f"Output: {out_file}")
if gate_failures:
    raise SystemExit(2)
PY
