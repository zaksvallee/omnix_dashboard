# Layer 2 Cutover Runbook

Status: operator-facing procedure for the MS Vallee Layer 2 test-site reset.
Scope: one-time reset of the owner-operated MS Vallee test corpus. This is not
precedent for commercial sites.

Ground truth:
- `audit/phase_5_section_3_cutover_policy.md`
- `audit/phase_5_section_3_amendment_1.md`
- `audit/phase_5_section_3_amendment_2.md`
- `supabase/manual/cutover/manifest.yaml`

Do not run destructive steps from automation. Steps 1-4 are read-only or local
file writes. Step 5 is the first database mutation and requires explicit
operator confirmation in chat immediately before execution.

## 0. Operator Shell Setup

Run from the repo root.

```sh
git status -sb
python3 -m pip install --user --break-system-packages -r scripts/requirements-cutover.txt
```

Set the database URL without printing the password. This uses the same linked
Supabase CLI credential source as the drift detector, then keeps the secret in
the current shell environment only.

```sh
set +x
export DATABASE_URL="$(
  PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import re
import subprocess
import sys
import urllib.parse

result = subprocess.run(
    ["supabase", "db", "dump", "--dry-run", "--linked"],
    capture_output=True,
    text=True,
    timeout=45,
)
if result.returncode != 0:
    print("supabase db dump --dry-run --linked failed", file=sys.stderr)
    print(result.stderr[-1000:], file=sys.stderr)
    raise SystemExit(2)

env = {}
for line in result.stdout.splitlines():
    m = re.match(r'^export\s+(PG(?:HOST|PORT|USER|PASSWORD|DATABASE))="(.+)"\s*$', line)
    if m:
        env[m.group(1)] = m.group(2)

required = ("PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE")
missing = [key for key in required if key not in env]
if missing:
    print(f"missing linked Supabase PG vars: {missing}", file=sys.stderr)
    raise SystemExit(2)

user = urllib.parse.quote(env["PGUSER"], safe="")
password = urllib.parse.quote(env["PGPASSWORD"], safe="")
database = urllib.parse.quote(env["PGDATABASE"], safe="")
print(
    f"postgresql://{user}:{password}@{env['PGHOST']}:{env['PGPORT']}/{database}"
    "?sslmode=require"
)
PY
)"
export CUTOVER_DB_ROLE=postgres
test -n "$DATABASE_URL"
```

If the operator supplies an already-privileged direct Postgres URL instead of
the Supabase CLI-derived URL, `CUTOVER_DB_ROLE` may be left empty.

Use one run timestamp for both exports:

```sh
export RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
export AS_OF="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## 1. Pre-Flight Verification

Required state before proceeding:
- `git status -sb` shows `main...origin/main` with no local changes.
- The drift detector is green.
- `supabase/manual/cutover/manifest.yaml` has `schema_version: 1`.
- `supabase/manual/post_cutover_constraints/` has been reviewed.
- No operator actions are planned against the dashboard during the wipe window.

Command:

```sh
python3 scripts/schema_drift_check.py --self-test
```

Abort if the drift detector fails.

## 2. Operator Confirmation Gate

Before any real export, the operator confirms in chat:

```text
CONFIRM LAYER 2 EXPORTS FOR MS VALLEE TEST SITE
```

This gate does not authorize wipe. Wipe has a separate gate in step 5.

## 3. QA Corpus Freeze

First run the read-only rehearsal:

```sh
python3 scripts/cutover_qa_corpus_freeze.py \
  --dry-run \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE" \
  --run-timestamp "$RUN_TS" \
  --as-of "$AS_OF" \
  --timestamp-overrides supabase/manual/cutover/qa_timestamp_overrides.yaml
```

Expected dry-run result from Phase B2 validation:
- 102 wipe tables planned.
- 0 exclusions.
- 28,384 planned rows at validation time.

If the dry-run refuses, abort and resolve the refusal before continuing.

Run the real local export only after the dry-run is clean:

```sh
python3 scripts/cutover_qa_corpus_freeze.py \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE" \
  --run-timestamp "$RUN_TS" \
  --as-of "$AS_OF" \
  --timestamp-overrides supabase/manual/cutover/qa_timestamp_overrides.yaml
```

Verify the archive exists and is parseable:

```sh
test -f "supabase/manual/cutover/exports/$RUN_TS/qa_corpus_index.json"
python3 -m json.tool "supabase/manual/cutover/exports/$RUN_TS/qa_corpus_index.json" >/dev/null
find "supabase/manual/cutover/exports/$RUN_TS/qa_corpus" -name '*.json' | wc -l
```

Abort if the index is missing, unparsable, or unexpectedly empty.

## 4. Preservation Export

First run the read-only rehearsal:

```sh
python3 scripts/cutover_preservation_export.py \
  --dry-run \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE" \
  --run-timestamp "$RUN_TS"
```

Expected dry-run result from Phase B2 validation:
- 18 concrete preservation tables planned.
- 61 planned rows at validation time.
- `auth.*` logged as preserved by non-action, not exportable by this script.

Run the real local export only after the dry-run is clean:

```sh
python3 scripts/cutover_preservation_export.py \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE" \
  --run-timestamp "$RUN_TS"
```

Verify the archive exists and is parseable:

```sh
test -f "supabase/manual/cutover/exports/$RUN_TS/preservation_index.json"
python3 -m json.tool "supabase/manual/cutover/exports/$RUN_TS/preservation_index.json" >/dev/null
find "supabase/manual/cutover/exports/$RUN_TS/preservation" -name '*.json' | wc -l
```

Abort if the preservation index is missing, unparsable, or if the row counts do
not match the clean dry-run immediately preceding the export.

## 5. Wipe Gate

This is the first destructive step. Do not proceed unless all conditions are
true:
- Steps 1-4 completed in the same operator session.
- Both export indexes are parseable.
- The operator has copied or otherwise protected the local export directory.
- `supabase/manual/cutover/wipe.sql` has been generated from this exact
  manifest revision and reviewed.
- The generated wipe SQL explicitly handles the `public.vehicles` to
  `public.employees` FK without truncating `public.vehicles`.
- The generated wipe SQL never touches preservation, untouched, `auth.*`,
  storage, realtime, vault, or Supabase migration schemas except for the
  deliberate `public.vehicles.assigned_employee_id` nulling required before
  `public.employees` is wiped.

Validate that the checked-in wipe SQL still matches the manifest:

```sh
python3 scripts/cutover_generate_wipe_sql.py --check
```

The wipe SQL preflight also refuses if live FK assumptions drift, if
`public.checkins` or `public.deployments` are no longer empty, or if an
unexpected external FK references a wipe target.

Required chat confirmation immediately before execution:

```text
PROCEED LAYER 2 WIPE FOR MS VALLEE TEST SITE
```

Do not use ad hoc `TRUNCATE ... CASCADE` in a shell. The manifest has a known
preservation-to-wipe FK:

```text
public.vehicles.assigned_employee_id -> public.employees
```

If the `--check` command fails, stop here. That is a successful abort, not a
failure.

Run the reviewed wipe SQL only after the chat confirmation above:

```sh
if [ -n "$CUTOVER_DB_ROLE" ]; then
  psql "$DATABASE_URL" \
    -v ON_ERROR_STOP=1 \
    -c "SET ROLE $CUTOVER_DB_ROLE" \
    -f supabase/manual/cutover/wipe.sql
else
  psql "$DATABASE_URL" \
    -v ON_ERROR_STOP=1 \
    -f supabase/manual/cutover/wipe.sql
fi
```

## 6. Post-Wipe Verification

Immediately after the reviewed wipe command completes, verify preservation row
counts before applying 4b constraints. The known content change is
`public.vehicles.assigned_employee_id`, which is intentionally nulled at the
wipe gate because it points at wiped dummy employee rows.

```sh
python3 scripts/cutover_preservation_export.py \
  --dry-run \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE" \
  --run-timestamp "$RUN_TS"
```

Compare the dry-run table counts to:

```sh
python3 -m json.tool "supabase/manual/cutover/exports/$RUN_TS/preservation_index.json"
```

Abort if any preservation row count changed. Do not apply constraints. Use the
preservation JSON archive as the restore source, and restore only through a
reviewed transaction.

## 7. Apply 4b Constraints

Apply these only after post-wipe preservation verification passes.

Run the read-only readiness check first:

```sh
python3 scripts/cutover_4b_readiness_check.py \
  --confirm-live \
  --db-role "$CUTOVER_DB_ROLE"
```

Abort if the readiness check reports any blocker. In the pre-cutover live
probe, the known preservation-side blocker is `public.clients.name = 'test'`
with three rows; because `public.clients` is preserved, the wipe will not clear
that duplicate group. Resolve it through reviewed preservation cleanup or defer
`clients_name_unique` before applying 4b constraints.

```sh
for file in \
  supabase/manual/post_cutover_constraints/04_add_unique_constraints_dirty.sql \
  supabase/manual/post_cutover_constraints/01_add_fk_promotions_dirty.sql \
  supabase/manual/post_cutover_constraints/02_add_not_null_dirty_columns.sql \
  supabase/manual/post_cutover_constraints/03_add_check_constraints_dirty_enums.sql
do
  if [ -n "$CUTOVER_DB_ROLE" ]; then
    psql "$DATABASE_URL" \
      -v ON_ERROR_STOP=1 \
      -c "SET ROLE $CUTOVER_DB_ROLE" \
      -f "$file"
  else
    psql "$DATABASE_URL" \
      -v ON_ERROR_STOP=1 \
      -f "$file"
  fi
done
```

Abort on the first failure. Do not declare cutover complete until the failure is
diagnosed and either fixed or explicitly rolled back.

## 8. Drift Detector Re-Run

```sh
python3 scripts/schema_drift_check.py --self-test
```

Cutover is not complete unless this returns green.

## 9. Forward Discipline

After cutover:
- All schema changes go through `supabase/migrations/`.
- No out-of-band `ALTER` statements.
- Generated export payloads stay under `supabase/manual/cutover/exports/` and
  remain gitignored.
- Record the `RUN_TS`, export row counts, wipe command identifier, constraint
  files applied, and drift-detector result in the operator chat or a follow-up
  audit note.

## Abort And Rollback Notes

Abort before step 5: stop. No database mutation has occurred.

Abort after step 5 but before step 7: keep the dashboard quiet, do not apply
constraints, and verify preservation counts. If preservation changed, restore
from `exports/$RUN_TS/preservation/` through reviewed SQL only.

Abort during step 7: stop at the failing constraint file. Do not continue to the
next file. Diagnose against the wiped live schema and the 4b file header
prerequisites.

Abort after step 8 failure: cutover is not complete. Keep all generated exports
and terminal output. Resolve drift through the normal migration chain or a
reviewed rollback; do not patch live manually.
