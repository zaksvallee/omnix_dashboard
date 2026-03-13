#!/usr/bin/env bash
set -euo pipefail

CURRENT_REPORT_JSON=""
PREVIOUS_REPORT_JSON=""
OUT_DIR=""
ALLOW_MATCH_RATE_DROP_PERCENT=0
ALLOW_MAX_SKEW_INCREASE_SECONDS=0
ALLOW_DRIFT_COUNT_INCREASES=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_parity_trend_check.sh [--current-report-json <path>] [--previous-report-json <path>] [--out-dir <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-drift-count-increase <reason=count>]...

Purpose:
  Compare one listener parity report against the previous run and fail when
  match rate regresses, observed skew increases, or drift counts worsen beyond
  the allowed thresholds.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-report-json)
      CURRENT_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --previous-report-json)
      PREVIOUS_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --allow-match-rate-drop-percent)
      ALLOW_MATCH_RATE_DROP_PERCENT="${2:-0}"
      shift 2
      ;;
    --allow-max-skew-increase-seconds)
      ALLOW_MAX_SKEW_INCREASE_SECONDS="${2:-0}"
      shift 2
      ;;
    --allow-drift-count-increase)
      ALLOW_DRIFT_COUNT_INCREASES+=("${2:-}")
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

if ! [[ "$ALLOW_MATCH_RATE_DROP_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --allow-match-rate-drop-percent must be a non-negative number."
  exit 1
fi
if ! [[ "$ALLOW_MAX_SKEW_INCREASE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-max-skew-increase-seconds must be a non-negative integer."
  exit 1
fi
for drift_cap in "${ALLOW_DRIFT_COUNT_INCREASES[@]-}"; do
  [[ -n "$drift_cap" ]] || continue
  if ! [[ "$drift_cap" =~ ^[A-Za-z0-9_:-]+=[0-9]+$ ]]; then
    echo "FAIL: --allow-drift-count-increase must use reason=count."
    exit 1
  fi
done

latest_reports() {
  local base_dir="tmp/listener_parity"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null
}

if [[ -z "$CURRENT_REPORT_JSON" ]]; then
  CURRENT_REPORT_JSON="$(latest_reports | sed -n '1p' || true)"
fi
if [[ -z "$CURRENT_REPORT_JSON" || ! -f "$CURRENT_REPORT_JSON" ]]; then
  echo "FAIL: current listener parity report not found."
  exit 1
fi

if [[ -z "$PREVIOUS_REPORT_JSON" ]]; then
  PREVIOUS_REPORT_JSON="$(
    latest_reports \
      | awk -v current="$CURRENT_REPORT_JSON" '$0 != current { print; exit }' \
      || true
  )"
fi
if [[ -z "$PREVIOUS_REPORT_JSON" || ! -f "$PREVIOUS_REPORT_JSON" ]]; then
  echo "FAIL: previous listener parity report not found."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$CURRENT_REPORT_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$CURRENT_REPORT_JSON" "$PREVIOUS_REPORT_JSON" "$OUT_DIR" "$ALLOW_MATCH_RATE_DROP_PERCENT" "$ALLOW_MAX_SKEW_INCREASE_SECONDS" "${ALLOW_DRIFT_COUNT_INCREASES[@]-}" <<'PY'
import json
import sys
from pathlib import Path

current_path = Path(sys.argv[1])
previous_path = Path(sys.argv[2])
out_dir = Path(sys.argv[3])
allow_match_drop = float(sys.argv[4])
allow_skew_increase = int(sys.argv[5])
allow_drift_increases = {}
for token in sys.argv[6:]:
    if not token:
        continue
    reason, count = token.split("=", 1)
    allow_drift_increases[reason] = int(count)

with current_path.open("r", encoding="utf-8") as handle:
    current = json.load(handle)
with previous_path.open("r", encoding="utf-8") as handle:
    previous = json.load(handle)

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

def report_chain_regressions(report, label):
    regressions = []
    files = report.get("files", {}) or {}
    serial_input = str(files.get("serial_input", "")).strip()
    legacy_input = str(files.get("legacy_input", "")).strip()
    report_markdown = str(files.get("report_markdown", "")).strip()
    if serial_input and not path_exists(serial_input):
        regressions.append({
            "code": f"{label}_report_missing_serial_input",
            "kind": "report_chain_missing_file",
            "report_label": label,
            "missing_field": "serial_input",
            "missing_path": serial_input,
        })
    if legacy_input and not path_exists(legacy_input):
        regressions.append({
            "code": f"{label}_report_missing_legacy_input",
            "kind": "report_chain_missing_file",
            "report_label": label,
            "missing_field": "legacy_input",
            "missing_path": legacy_input,
        })
    if report_markdown and not path_exists(report_markdown):
        regressions.append({
            "code": f"{label}_report_missing_report_markdown",
            "kind": "report_chain_missing_file",
            "report_label": label,
            "missing_field": "report_markdown",
            "missing_path": report_markdown,
        })
    return regressions

current_drift = current.get("drift_reason_counts", {}) or {}
previous_drift = previous.get("drift_reason_counts", {}) or {}
all_reasons = sorted(set(current_drift) | set(previous_drift))

current_match_rate = float(current.get("match_rate_percent", 0.0) or 0.0)
previous_match_rate = float(previous.get("match_rate_percent", 0.0) or 0.0)
current_max_skew = int(float(current.get("max_skew_seconds_observed", 0) or 0))
previous_max_skew = int(float(previous.get("max_skew_seconds_observed", 0) or 0))

regressions = []
regressions.extend(report_chain_regressions(current, "current"))
regressions.extend(report_chain_regressions(previous, "previous"))
match_rate_drop = round(previous_match_rate - current_match_rate, 2)
if match_rate_drop > allow_match_drop:
    regressions.append(
        {
            "code": "match_rate_drop",
            "kind": "match_rate_drop",
            "previous": previous_match_rate,
            "current": current_match_rate,
            "delta": round(current_match_rate - previous_match_rate, 2),
            "allowed_drop": allow_match_drop,
        }
    )

max_skew_increase = current_max_skew - previous_max_skew
if max_skew_increase > allow_skew_increase:
    regressions.append(
        {
            "code": "max_skew_increase",
            "kind": "max_skew_increase",
            "previous": previous_max_skew,
            "current": current_max_skew,
            "delta": max_skew_increase,
            "allowed_increase": allow_skew_increase,
        }
    )

drift_deltas = []
for reason in all_reasons:
    current_count = int(current_drift.get(reason, 0) or 0)
    previous_count = int(previous_drift.get(reason, 0) or 0)
    delta = current_count - previous_count
    drift_deltas.append(
        {
            "reason": reason,
            "previous_count": previous_count,
            "current_count": current_count,
            "delta": delta,
            "allowed_increase": allow_drift_increases.get(reason, 0),
        }
    )
    if delta > allow_drift_increases.get(reason, 0):
        regressions.append(
            {
                "code": "drift_count_increase",
                "kind": "drift_count_increase",
                "reason": reason,
                "previous": previous_count,
                "current": current_count,
                "delta": delta,
                "allowed_increase": allow_drift_increases.get(reason, 0),
            }
        )

status = "PASS" if not regressions else "FAIL"
result = {
    "status": status,
    "current_report_json": str(current_path),
    "previous_report_json": str(previous_path),
    "current_summary": current.get("summary", ""),
    "previous_summary": previous.get("summary", ""),
    "metrics": {
        "match_rate_percent": {
            "previous": previous_match_rate,
            "current": current_match_rate,
            "delta": round(current_match_rate - previous_match_rate, 2),
            "allowed_drop": allow_match_drop,
        },
        "max_skew_seconds_observed": {
            "previous": previous_max_skew,
            "current": current_max_skew,
            "delta": max_skew_increase,
            "allowed_increase": allow_skew_increase,
        },
    },
    "drift_deltas": drift_deltas,
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
    "regressions": regressions,
}

json_out = out_dir / "trend_report.json"
md_out = out_dir / "trend_report.md"
json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Parity Trend Report",
    "",
    f"- Status: `{status}`",
    f"- Current report: `{current_path}`",
    f"- Previous report: `{previous_path}`",
    "",
    "## Summary",
    f"- Current: `{result['current_summary']}`",
    f"- Previous: `{result['previous_summary']}`",
    "",
    "## Metric Deltas",
    f"- Match rate: `{previous_match_rate:.2f}% -> {current_match_rate:.2f}%` (delta `{current_match_rate - previous_match_rate:.2f}%`, allowed drop `{allow_match_drop:.2f}%`)",
    f"- Max observed skew: `{previous_max_skew}s -> {current_max_skew}s` (delta `{max_skew_increase}s`, allowed increase `{allow_skew_increase}s`)",
    "",
    "## Drift Deltas",
]
if drift_deltas:
    for item in drift_deltas:
        lines.append(
            f"- `{item['reason']}`: `{item['previous_count']} -> {item['current_count']}` "
            f"(delta `{item['delta']}`, allowed increase `{item['allowed_increase']}`)"
        )
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "drift_count_increase":
            lines.append(
                f"- `{item['code']}` on `{item['reason']}`: "
                f"`{item['previous']} -> {item['current']}` "
                f"(delta `{item['delta']}`, allowed `{item['allowed_increase']}`)"
            )
        elif item["kind"] == "report_chain_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` report missing "
                f"`{item['missing_field']}` at `{item['missing_path']}`"
            )
        else:
            lines.append(
                f"- `{item['code']}`: `{item['previous']} -> {item['current']}` "
                f"(delta `{item['delta']}`, allowance "
                f"`{item.get('allowed_drop', item.get('allowed_increase'))}`)"
            )
else:
    lines.append("- None")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"{status}: Listener parity trend JSON written to {json_out}")
print(f"{status}: Listener parity trend markdown written to {md_out}")
print(f"Current summary: {result['current_summary']}")
print(f"Previous summary: {result['previous_summary']}")
if regressions:
    for item in regressions:
        if item["kind"] == "drift_count_increase":
            print(
                "Regression:"
                f" {item['code']} on {item['reason']}"
                f" ({item['previous']} -> {item['current']},"
                f" delta {item['delta']}, allowed {item['allowed_increase']})"
            )
        elif item["kind"] == "report_chain_missing_file":
            print(
                "Regression:"
                f" {item['code']}"
                f" ({item['report_label']} missing {item['missing_field']}:"
                f" {item['missing_path']})"
            )
        else:
            print(
                "Regression:"
                f" {item['code']}"
                f" ({item['previous']} -> {item['current']},"
                f" delta {item['delta']}, allowance"
                f" {item.get('allowed_drop', item.get('allowed_increase'))})"
            )

if regressions:
    raise SystemExit(1)
PY
