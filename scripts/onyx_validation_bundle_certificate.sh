#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
OUT_JSON=""
OUT_MD=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_validation_bundle_certificate.sh --report-json <path> [--out-json <path>] [--out-md <path>]

Purpose:
  Generate a deterministic integrity certificate for a staged ONYX validation
  bundle (CCTV, DVR, listener, or other validation_report.json shape).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json) REPORT_JSON="${2:-}"; shift 2 ;;
    --out-json) OUT_JSON="${2:-}"; shift 2 ;;
    --out-md) OUT_MD="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  echo "FAIL: validation report not found."
  exit 1
fi

artifact_dir="$(python3 - "$REPORT_JSON" <<'PY'
import json, pathlib, sys
report = pathlib.Path(sys.argv[1])
data = json.loads(report.read_text(encoding='utf-8'))
artifact_dir = str(data.get('artifact_dir', '')).strip()
print(artifact_dir or str(report.parent))
PY
)"

if [[ -z "$OUT_JSON" ]]; then
  OUT_JSON="$artifact_dir/integrity_certificate.json"
fi
if [[ -z "$OUT_MD" ]]; then
  OUT_MD="$artifact_dir/integrity_certificate.md"
fi

mkdir -p "$(dirname "$OUT_JSON")"
mkdir -p "$(dirname "$OUT_MD")"

python3 - "$REPORT_JSON" "$OUT_JSON" "$OUT_MD" <<'PY'
import hashlib
import json
import os
import pathlib
import sys
from datetime import datetime, timezone

report_path = pathlib.Path(sys.argv[1])
out_json = pathlib.Path(sys.argv[2])
out_md = pathlib.Path(sys.argv[3])
data = json.loads(report_path.read_text(encoding="utf-8"))

artifact_dir = pathlib.Path(str(data.get("artifact_dir", "")).strip() or report_path.parent)
files = data.get("files") or {}
checksums = data.get("checksums") or {}

def sha_file(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

bundle_files = []
failures = []
for key, raw_path in sorted(files.items()):
    path_str = str(raw_path or "").strip()
    if not path_str:
        continue
    path = pathlib.Path(path_str)
    checksum_key = f"{key}_sha256"
    expected = str(checksums.get(checksum_key, "") or "").strip()
    present = path.is_file()
    actual = sha_file(path) if present else ""
    checksum_match = bool(expected and present and actual == expected)
    if expected and not present:
      failures.append({
        "code": f"{key}_missing",
        "message": f"Bundle file {key} is missing: {path}",
      })
    elif expected and not checksum_match:
      failures.append({
        "code": f"{key}_checksum_mismatch",
        "message": f"Bundle file {key} checksum does not match the validation report.",
      })
    bundle_files.append({
      "key": key,
      "path": str(path),
      "expected_sha256": expected,
      "actual_sha256": actual,
      "present": present,
      "checksum_match": checksum_match if expected else present,
    })

bundle_payload = {
    "report_json": str(report_path),
    "artifact_dir": str(artifact_dir),
    "generated_at_utc": str(data.get("generated_at_utc", "")).strip(),
    "overall_status": str(data.get("overall_status", "")).strip(),
    "is_mock": bool(data.get("is_mock", False)),
    "bundle_files": [
        {
            "key": entry["key"],
            "path": entry["path"],
            "actual_sha256": entry["actual_sha256"],
        }
        for entry in bundle_files
    ],
}
bundle_hash = hashlib.sha256(
    json.dumps(bundle_payload, sort_keys=True).encode("utf-8")
).hexdigest()

status = "PASS" if not failures else "FAIL"
summary = (
    "Validation bundle integrity verified."
    if status == "PASS"
    else "Validation bundle integrity failed."
)

report = {
    "certificate_type": "onyx_validation_bundle_integrity_certificate",
    "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "status": status,
    "summary": summary,
    "report_json": str(report_path),
    "artifact_dir": str(artifact_dir),
    "overall_status": str(data.get("overall_status", "")).upper(),
    "is_mock": bool(data.get("is_mock", False)),
    "bundle_hash": bundle_hash,
    "bundle_files": bundle_files,
    "failure_codes": [item["code"] for item in failures],
    "failures": failures,
  }

out_json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
out_md.write_text(
    "\n".join(
        [
            "# ONYX Validation Bundle Integrity Certificate",
            "",
            f"- Status: {status}",
            f"- Summary: {summary}",
            f"- Validation report: `{report_path}`",
            f"- Artifact dir: `{artifact_dir}`",
            f"- Overall status: `{str(data.get('overall_status', '')).upper() or 'UNKNOWN'}`",
            f"- Mock bundle: `{'true' if bool(data.get('is_mock', False)) else 'false'}`",
            f"- Bundle hash: `{bundle_hash}`",
            "",
            "## Files",
            *[
                f"- `{entry['key']}` • present={str(entry['present']).lower()} • match={str(entry['checksum_match']).lower()} • `{entry['actual_sha256'] or 'missing'}`"
                for entry in bundle_files
            ],
            "",
            "## Failures",
            *([f"- {item['message']} (`{item['code']}`)" for item in failures] or ["- none"]),
        ]
    )
    + "\n",
    encoding="utf-8",
)

print(out_json)
print(out_md)
print(status)
if failures:
    sys.exit(1)
PY
