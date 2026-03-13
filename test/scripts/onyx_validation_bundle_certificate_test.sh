#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$ROOT_DIR/tmp/validation_bundle_certificate_test"
find "$tmp_dir" -type f -delete 2>/dev/null || true
find "$tmp_dir" -type d -empty -delete 2>/dev/null || true
mkdir -p "$tmp_dir"

cat >"$tmp_dir/sample.txt" <<'EOF'
sample
EOF

sample_sha="$(python3 - "$tmp_dir/sample.txt" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

cat >"$tmp_dir/validation_report.json" <<EOF
{
  "generated_at_utc": "2026-03-13T12:00:00Z",
  "artifact_dir": "$tmp_dir",
  "overall_status": "PASS",
  "is_mock": true,
  "files": {
    "sample": "$tmp_dir/sample.txt"
  },
  "checksums": {
    "sample_sha256": "$sample_sha"
  }
}
EOF

bash ./scripts/onyx_validation_bundle_certificate.sh \
  --report-json "$tmp_dir/validation_report.json" \
  --out-json "$tmp_dir/cert.json" \
  --out-md "$tmp_dir/cert.md" >/dev/null

python3 - "$tmp_dir/cert.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert data["status"] == "PASS"
assert data["bundle_hash"]
assert data["failure_codes"] == []
PY

python3 - "$tmp_dir/validation_report.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["checksums"]["sample_sha256"] = "bad"
path.write_text(json.dumps(data, indent=2) + "\n")
PY

if bash ./scripts/onyx_validation_bundle_certificate.sh \
  --report-json "$tmp_dir/validation_report.json" \
  --out-json "$tmp_dir/cert_fail.json" \
  --out-md "$tmp_dir/cert_fail.md" >/dev/null; then
  echo "Expected checksum-mismatch failure" >&2
  exit 1
fi

python3 - "$tmp_dir/cert_fail.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert data["status"] == "FAIL"
assert "sample_checksum_mismatch" in data["failure_codes"]
PY

find "$tmp_dir" -type f -delete
find "$tmp_dir" -type d -empty -delete
