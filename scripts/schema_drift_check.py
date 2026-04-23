#!/usr/bin/env python3
# ============================================================================
# ONYX Schema Drift Detector
# ============================================================================
#
# Purpose:
#   Compare live Supabase schema against the active migration chain and
#   report any divergence in human-readable form. Prevents the ghost-schema
#   problem (phase 4 §2, Step 1 inventory §1) from recurring: if any change
#   is made to the live DB outside the migration chain, this script surfaces
#   it on the next run.
#
# Context:
#   Layer 1 Step 3 of the audit remediation. Steps 1 (baseline) and 2
#   (reconciliation) established a single-active-migration chain —
#   supabase/migrations/20260421000000_reverse_engineered_baseline.sql is
#   the sole active-chain file; 44 historical migrations are quarantined in
#   supabase/migrations/historical/ and 10 in deploy/supabase_migrations/
#   historical/. This script is manual-run: no CI, no hooks, no enforcement.
#   If it reports drift, the drift must be resolved before any further
#   schema work — either by adding a migration that captures the change, or
#   by reverting the out-of-band change in live.
#
# Usage:
#   python scripts/schema_drift_check.py           # plain-text report
#   python scripts/schema_drift_check.py --verbose # + attribute-level detail
#   python scripts/schema_drift_check.py --json    # JSON output, same hierarchy
#   python scripts/schema_drift_check.py --self-test  # assert expected state
#
# Exit codes:
#   0 = clean (zero drift detected)
#   1 = drift detected (report lists findings)
#   2 = error (pre-flight or provision failure — no comparison attempted)
#
# ----------------------------------------------------------------------------
# Phase A design decisions (2026-04-21)
# ----------------------------------------------------------------------------
#
# 1. Credential discovery — reuse Step 1's path:
#    `supabase db dump --dry-run --linked` emits a bash script carrying the
#    CLI's stored PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE (from
#    `supabase login`). Script shells out to it once, parses the env-var
#    assignments, uses them directly with pg_dump. No credential hunting in
#    config files. No credentials logged to stdout.
#
# 2. Live capture — `pg_dump --schema-only` via Homebrew postgresql@17
#    (matches the live server's PG17.6 to avoid version-mismatch rejection).
#    Same flag set the Supabase CLI generates internally: --quote-all-
#    identifier --role postgres --exclude-schema=<Supabase internal list>.
#    Output written to a tempfile, parsed in-process. READ-ONLY against live;
#    no DDL/DML ever issued against the Supabase project.
#
# 3. Scratch provisioning — Homebrew postgresql@17, per-run tempdir via
#    tempfile.mkdtemp(prefix="onyx_drift_"). Port 55432 (probed before
#    start — abort if busy rather than guess). Lifecycle: initdb → pg_ctl
#    start → createdb → prep (schemas, roles, extensions, auth stubs,
#    storage.objects + storage.buckets stubs) → apply baseline →
#    pg_dump scratch → pg_ctl stop
#    → rm -rf tempdir. Cleanup runs under try/finally AND atexit — scratch
#    is dropped on clean exit, exception, assertion failure, SIGTERM, or
#    Ctrl-C.
#
# 4. PostGIS: Option A (build-time decision, not per-run).
#    `brew install postgis` on 2026-04-21 installed cleanly (precompiled
#    bottle, 86 MB + 11 deps, ~3 min). `CREATE EXTENSION postgis` in PG17
#    scratch tested working; `geometry` and `geography` types + ST_AsText
#    etc. functional. Tool therefore assumes PostGIS is available on the
#    machine running it and creates the extension in scratch during prep.
#    If CREATE EXTENSION postgis fails at runtime, script exits 2 with
#    a message directing the operator to `brew install postgis`. Option B
#    (exclusion list) is not implemented; its fallback complexity is not
#    justified when Option A works. Documented in scripts/schema_drift_
#    check.md.
#
# 5. Auth stub set (baked in per Step 2 §6.5):
#      auth.uid()  -> NULL::uuid
#      auth.jwt()  -> '{}'::jsonb
#      auth.role() -> NULL::text    <- Step 2 §6.5 action item
#    If Phase B comparison discovers references to other auth.* functions
#    in live policy bodies, they are added here and documented in the
#    audit note.
#
# 6. Output format — plain text stdout, structured sections (SUMMARY /
#    GHOST OBJECTS / ORPHANED OBJECTS / ATTRIBUTE MISMATCHES / KNOWN
#    LIMITATIONS / EXIT STATUS). Never ANSI-colored (the --no-color flag
#    is a no-op kept for ergonomic compat with automation scripts). --json
#    re-emits the same hierarchy as JSON. --verbose adds column-level diff
#    for tables in-both.
#
# 7. Self-test — `--self-test` asserts the expected state against Step 1 /
#    Step 2 documented findings (Option A branch): zero drift across every
#    category (129 tables / 24 views / 32 fns / 37 triggers / 157 policies
#    / 14 enums / 2 sequences / 63 RLS-enabled / 57 FKs all match). If the
#    assertion fails, one of three things is true: script bug, live
#    changed, or Step 1/2 missed something. Self-test exits 1 with a
#    precise delta so the operator can diagnose.
#
# ============================================================================

import argparse
import atexit
import json
import os
import re
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from datetime import datetime, timezone

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

SCRIPT_VERSION = "1.0.0"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS_DIR = os.path.join(REPO_ROOT, "supabase", "migrations")
PG17_BIN = "/opt/homebrew/opt/postgresql@17/bin"
PG_DUMP = f"{PG17_BIN}/pg_dump"
PG_CTL = f"{PG17_BIN}/pg_ctl"
INITDB = f"{PG17_BIN}/initdb"
PSQL = f"{PG17_BIN}/psql"
SCRATCH_PORT = 55432

# Supabase internal schemas to exclude from pg_dump on the live side.
# This list matches what `supabase db dump --dry-run --linked` emits.
EXCLUDE_SCHEMA = (
    "information_schema|pg_*|_analytics|_realtime|_supavisor|auth|extensions|"
    "pgbouncer|realtime|storage|supabase_functions|supabase_migrations|cron|"
    "dbdev|graphql|graphql_public|net|pgmq|pgsodium|pgsodium_masks|pgtle|"
    "repack|tiger|tiger_data|timescaledb_*|_timescaledb_*|topology|vault"
)

# Self-test expected state — Post-Layer-1-Step-4 target.
# After Step 4a applied to live via `supabase db push --linked` on 2026-04-22
# (commits 9af9309 + a0953fb), live had +14 FKs, +11 CHECKs, +3 UNIQUE,
# +13 indexes (10 new + 3 backing), +5 RLS-enabled tables, +10 policies.
# After Layer 2 cutover step 7 on 2026-04-23, live additionally has the
# post-cutover 4b capture migration's +9 FK promotions. CHECK / UNIQUE /
# NOT NULL additions also landed, but this detector currently tracks only FK
# counts among table constraints. If live changes out of band, these numbers
# change and the assertion fails.
SELF_TEST_EXPECTED = {
    "tables": 129,        # Step 4a adds no tables
    "views": 24,          # no new views
    "functions_public": 32,
    "triggers": 37,
    "policies": 167,      # 157 pre-4a + 10 Step 4a (5 tables × 2 policies)
    "enums_public": 14,
    "sequences_public": 2,
    "rls_enabled": 68,    # 63 + 5 Step 4a ENABLE
    "foreign_keys": 80,   # 57 + 14 Step 4a FK promotions + 9 Layer 2 post-cutover FKs
    # After Step 2's quarantine-to-historical/ pattern, the active chain is
    # the baseline alone — so live vs scratch drift is expected to be zero
    # across every category (Option A branch).
    # Ghost (in live, not in chain) — out-of-band additions to live
    "ghost_tables": 0,
    "ghost_columns": 0,
    "missing_policies": 0,       # policies in live not in chain (named "missing"
    "missing_fks": 0,            # because the chain is "missing" them — legacy
    "missing_views": 0,          # naming retained to avoid breaking callers)
    # Orphaned (in chain, not in live) — migrations declared but not applied
    "orphaned_tables": 0,
    "orphaned_columns": 0,
    "orphaned_foreign_keys": 0,
    "orphaned_policies": 0,
    "orphaned_views": 0,
    "orphaned_rls_enabled": 0,
}


# -----------------------------------------------------------------------------
# Cleanup registry — guaranteed scratch teardown
# -----------------------------------------------------------------------------

_cleanup_handlers = []


def _register_cleanup(fn):
    _cleanup_handlers.append(fn)


def _run_cleanup():
    # Run in reverse-registration order (LIFO) so pg_ctl stop happens
    # before rm -rf of its datadir.
    while _cleanup_handlers:
        fn = _cleanup_handlers.pop()
        try:
            fn()
        except Exception as e:
            # Cleanup failures must not mask the original error.
            print(f"[cleanup] warning: {e}", file=sys.stderr)


atexit.register(_run_cleanup)


def _signal_handler(signum, _frame):
    _run_cleanup()
    sys.exit(130 if signum == signal.SIGINT else 143)


signal.signal(signal.SIGINT, _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)


# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

def preflight():
    """Verify local tooling before doing any work. Exits 2 on failure."""
    problems = []
    if not os.path.isfile(PG_DUMP):
        problems.append(
            f"pg_dump 17 not found at {PG_DUMP}. Install via `brew install postgresql@17`."
        )
    if not os.path.isfile(PSQL):
        problems.append(f"psql 17 not found at {PSQL}. `brew install postgresql@17`.")
    if shutil.which("supabase") is None:
        problems.append(
            "Supabase CLI not on PATH. `brew install supabase/tap/supabase` and `supabase login` + `supabase link --project-ref <ref>`."
        )
    # Migration dir + baseline present?
    baseline = os.path.join(MIGRATIONS_DIR, "20260421000000_reverse_engineered_baseline.sql")
    if not os.path.isfile(baseline):
        problems.append(f"Active-chain baseline not found at {baseline} (Layer 1 Step 1 output).")
    # PostGIS extension control file?
    postgis_ctl = "/opt/homebrew/opt/postgresql@17/share/postgresql@17/extension/postgis.control"
    # NOTE: homebrew postgis installs its control file under /opt/homebrew/share/postgresql@17/
    # or similar; accept any readable postgis.control beneath /opt/homebrew/**
    try:
        out = subprocess.check_output(
            ["bash", "-lc", "find /opt/homebrew -name 'postgis.control' 2>/dev/null | head -1"],
            text=True,
        ).strip()
        if not out:
            problems.append(
                "PostGIS not installed. `brew install postgis`. Tool requires Option A (PostGIS in scratch) — see scripts/schema_drift_check.md §PostGIS handling."
            )
    except Exception:
        problems.append("Could not verify PostGIS availability.")
    # Port 55432 free?
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("127.0.0.1", SCRATCH_PORT)) == 0:
                problems.append(
                    f"Port {SCRATCH_PORT} already in use. Stop the other Postgres or choose a different port."
                )
    except Exception:
        pass

    if problems:
        print("ERROR: preflight failed:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        sys.exit(2)


# -----------------------------------------------------------------------------
# Supabase credential discovery
# -----------------------------------------------------------------------------

def discover_live_credentials():
    """Run `supabase db dump --dry-run --linked`, extract PGHOST/... env vars.

    Returns a dict of env vars. Read-only against live.
    """
    try:
        result = subprocess.run(
            ["supabase", "db", "dump", "--dry-run", "--linked"],
            capture_output=True, text=True, timeout=30,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"ERROR: supabase CLI call failed: {e}", file=sys.stderr)
        sys.exit(2)

    if result.returncode != 0:
        print("ERROR: `supabase db dump --dry-run --linked` failed", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(2)

    env = {}
    for line in result.stdout.splitlines():
        try:
            parts = shlex.split(line)
        except ValueError:
            continue
        if len(parts) != 2 or parts[0] != "export" or "=" not in parts[1]:
            continue
        key, value = parts[1].split("=", 1)
        if key in {"PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE"}:
            env[key] = value
    if not all(k in env for k in ("PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE")):
        print("ERROR: Could not extract all PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE from supabase CLI output.", file=sys.stderr)
        print("Is the project linked? Try `supabase link --project-ref <ref>`.", file=sys.stderr)
        sys.exit(2)
    return env


# -----------------------------------------------------------------------------
# Live schema dump
# -----------------------------------------------------------------------------

def dump_live_schema(live_env, out_path, verbose=False, timeout=900):
    """Dump live production schema via pg_dump. Read-only."""
    if verbose:
        # Redact password for logging
        redacted = {k: ("***" if k == "PGPASSWORD" else v) for k, v in live_env.items()}
        print(f"[live] pg_dump target: {redacted}", file=sys.stderr)

    # Same flags the Supabase CLI uses — preserves parity with Step 1 baseline.
    cmd = [
        PG_DUMP,
        "--schema-only",
        "--quote-all-identifier",
        "--role", "postgres",
        "--exclude-schema", EXCLUDE_SCHEMA,
    ]
    env = {**os.environ, **live_env}
    # Default 900s: remote pg_dump over the Supabase pooler is catalog-read-heavy. Direct
    # timing on 2026-04-21 measured ~8m10s (490s) wall clock for the current
    # 129-table schema; 900s gives ~1.8× margin for transient pooler slowness.
    print(
        f"[live] starting pg_dump --schema-only; this can take ~8-15 minutes "
        f"(timeout {timeout}s).",
        file=sys.stderr,
    )
    try:
        result = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f"ERROR: pg_dump of live timed out after {timeout}s.", file=sys.stderr)
        print("Check network connectivity to Supabase and retry. If this is", file=sys.stderr)
        print("recurrent, the schema may have grown past what a single pg_dump", file=sys.stderr)
        print("call can complete in the configured window — consider raising", file=sys.stderr)
        print("--live-dump-timeout.", file=sys.stderr)
        sys.exit(2)
    if result.returncode != 0:
        print(f"ERROR: pg_dump of live failed: {result.stderr[:500]}", file=sys.stderr)
        sys.exit(2)
    # Apply the same sed-chain sanitisation the Supabase CLI applies so that
    # live and scratch dumps are directly comparable.
    sanitised = _sanitise_dump(result.stdout)
    with open(out_path, "w") as f:
        f.write(sanitised)


def _sanitise_dump(sql):
    """Apply the Supabase CLI's standard sed sanitisation to make dumps
    comparable between live and scratch."""
    transforms = [
        (r'^(\\(un)?restrict .*)$', r'-- \1'),
        (r'^(CREATE SCHEMA) "', r'\1 IF NOT EXISTS "'),
        (r'^(CREATE TABLE) "', r'\1 IF NOT EXISTS "'),
        (r'^(CREATE SEQUENCE) "', r'\1 IF NOT EXISTS "'),
        (r'^(CREATE VIEW) "', r'CREATE OR REPLACE VIEW "'),
        (r'^(CREATE FUNCTION) "', r'CREATE OR REPLACE FUNCTION "'),
        (r'^(CREATE TRIGGER) "', r'CREATE OR REPLACE TRIGGER "'),
        (r'^(CREATE PUBLICATION "supabase_realtime)', r'-- \1'),
        (r'^(CREATE EVENT TRIGGER) ', r'-- \1 '),
        (r'^(         WHEN TAG IN )', r'-- \1'),
        (r'^(   EXECUTE FUNCTION )', r'-- \1'),
        (r'^(ALTER EVENT TRIGGER) ', r'-- \1 '),
        (r'^(ALTER PUBLICATION "supabase_realtime_)', r'-- \1'),
        (r'^(SET transaction_timeout = 0;)', r'-- \1'),
        (r'^--', r''),  # strip comment lines (matches CLI's `/^--/d`)
    ]
    out = []
    for line in sql.splitlines():
        for pat, repl in transforms:
            if re.match(pat, line):
                if repl == r'':
                    line = None
                    break
                line = re.sub(pat, repl, line)
        if line is not None:
            out.append(line)
    return "\n".join(out)


# -----------------------------------------------------------------------------
# Scratch Postgres lifecycle
# -----------------------------------------------------------------------------

def provision_scratch():
    """Spin up a fresh Postgres 17 instance in a tempdir. Registers cleanup."""
    scratch_dir = tempfile.mkdtemp(prefix="onyx_drift_")
    log_file = os.path.join(scratch_dir, "postgres.log")
    data_dir = os.path.join(scratch_dir, "data")

    def _teardown():
        try:
            subprocess.run(
                [PG_CTL, "-D", data_dir, "stop", "-m", "immediate"],
                capture_output=True, timeout=30,
            )
        except Exception:
            pass
        shutil.rmtree(scratch_dir, ignore_errors=True)

    _register_cleanup(_teardown)

    subprocess.run(
        [INITDB, "-D", data_dir, "-U", "postgres", "-A", "trust",
         "--encoding=UTF8", "--locale=en_US.UTF-8"],
        check=True, capture_output=True, timeout=60,
    )
    # Use socket dir inside tempdir so we don't collide with any other
    # postgres running on /tmp.
    pg_opts = f"-p {SCRATCH_PORT} -c unix_socket_directories='{scratch_dir}'"
    subprocess.run(
        [PG_CTL, "-D", data_dir, "-o", pg_opts, "-l", log_file, "start"],
        check=True, capture_output=True, timeout=30,
    )
    # Wait until ready.
    for _ in range(20):
        try:
            subprocess.run(
                [PSQL, "-h", scratch_dir, "-p", str(SCRATCH_PORT), "-U", "postgres",
                 "-d", "postgres", "-c", "SELECT 1", "-t"],
                check=True, capture_output=True, timeout=5,
            )
            break
        except Exception:
            time.sleep(0.5)
    return scratch_dir


def prep_scratch(scratch_dir, db_name="verify"):
    """Create the verify DB + apply Supabase-compat prep (schemas, roles,
    extensions, auth stubs, storage.objects + storage.buckets stubs)."""
    _psql(scratch_dir, "postgres", f"CREATE DATABASE {db_name};")
    prep_sql = """
    CREATE SCHEMA IF NOT EXISTS extensions;
    CREATE SCHEMA IF NOT EXISTS graphql;
    CREATE SCHEMA IF NOT EXISTS vault;
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS storage;
    CREATE ROLE service_role;
    CREATE ROLE authenticated;
    CREATE ROLE anon;
    CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
    CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;
    CREATE EXTENSION postgis WITH SCHEMA public;  -- Option A: PostGIS in scratch
    CREATE OR REPLACE FUNCTION auth.uid()  RETURNS uuid  LANGUAGE sql STABLE AS $$ SELECT NULL::uuid $$;
    CREATE OR REPLACE FUNCTION auth.jwt()  RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT '{}'::jsonb $$;
    CREATE OR REPLACE FUNCTION auth.role() RETURNS text  LANGUAGE sql STABLE AS $$ SELECT NULL::text  $$;
    CREATE TABLE IF NOT EXISTS storage.objects (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        bucket_id text, name text, owner uuid,
        created_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now(),
        last_accessed_at timestamptz, metadata jsonb,
        path_tokens text[], version text, owner_id text
    );
    CREATE TABLE IF NOT EXISTS storage.buckets (
        id text PRIMARY KEY, name text NOT NULL,
        owner uuid, public boolean DEFAULT false,
        created_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now(),
        file_size_limit bigint, allowed_mime_types text[],
        avif_autodetection boolean DEFAULT false
    );
    """
    _psql(scratch_dir, db_name, prep_sql)


def apply_active_chain(scratch_dir, db_name="verify", verbose=False):
    """Apply every *.sql in supabase/migrations/ (not historical/) in order.
    After Step 2, this is just the baseline."""
    files = sorted(
        f for f in os.listdir(MIGRATIONS_DIR)
        if f.endswith(".sql") and os.path.isfile(os.path.join(MIGRATIONS_DIR, f))
    )
    for f in files:
        path = os.path.join(MIGRATIONS_DIR, f)
        # With Option A, no sed-stripping needed — all extensions install.
        result = subprocess.run(
            [PSQL, "-h", scratch_dir, "-p", str(SCRATCH_PORT), "-U", "postgres",
             "-d", db_name, "-v", "ON_ERROR_STOP=0", "-f", path],
            capture_output=True, text=True, timeout=120,
        )
        # Apply with ON_ERROR_STOP=0 — mirror Step 1/2. Errors are surfaced
        # in stderr if --verbose so silent DDL failures (e.g. scratch stub
        # missing a referenced object) don't masquerade as drift.
        if verbose and result.stderr:
            errors = [line for line in result.stderr.splitlines()
                      if "ERROR:" in line or "FATAL:" in line]
            if errors:
                print(f"[scratch] {f}: {len(errors)} error line(s) during apply:",
                      file=sys.stderr)
                for line in errors[:20]:
                    print(f"  {line}", file=sys.stderr)


def dump_scratch_schema(scratch_dir, out_path, db_name="verify"):
    """pg_dump the scratch DB with the same flags used against live."""
    cmd = [
        PG_DUMP,
        "--schema-only",
        "--quote-all-identifier",
        "--role", "postgres",
        "--exclude-schema", EXCLUDE_SCHEMA,
        "-h", scratch_dir, "-p", str(SCRATCH_PORT), "-U", "postgres", "-d", db_name,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        print(f"ERROR: pg_dump of scratch failed: {result.stderr[:500]}", file=sys.stderr)
        sys.exit(2)
    sanitised = _sanitise_dump(result.stdout)
    with open(out_path, "w") as f:
        f.write(sanitised)


def _psql(scratch_dir, db, sql):
    subprocess.run(
        [PSQL, "-h", scratch_dir, "-p", str(SCRATCH_PORT), "-U", "postgres",
         "-d", db, "-v", "ON_ERROR_STOP=0", "-c", sql],
        capture_output=True, text=True, timeout=60,
    )


# -----------------------------------------------------------------------------
# Schema parsing + comparison (Phase B — the comparison logic)
# -----------------------------------------------------------------------------

def parse_schema(sql):
    """Extract object sets from a pg_dump schema-only output.

    Returns a dict with keys matching SELF_TEST_EXPECTED + per-table columns.
    """
    tables = set(re.findall(r'CREATE TABLE IF NOT EXISTS "public"\."([^"]+)"', sql))
    views = set(re.findall(r'CREATE OR REPLACE VIEW "public"\."([^"]+)"', sql))
    fns = set(re.findall(r'CREATE OR REPLACE FUNCTION "public"\."([^"]+)"', sql))
    triggers = set(re.findall(r'CREATE OR REPLACE TRIGGER "([^"]+)"', sql))
    enums = set(re.findall(r'CREATE TYPE "public"\."([^"]+)" AS ENUM', sql))
    sequences = set(re.findall(r'CREATE SEQUENCE IF NOT EXISTS "public"\."([^"]+)"', sql))
    indexes = set(re.findall(r'CREATE (?:UNIQUE )?INDEX (?:IF NOT EXISTS )?"([^"]+)"', sql))
    rls_enabled = set(re.findall(
        r'ALTER TABLE (?:ONLY )?"public"\."([^"]+)" ENABLE ROW LEVEL SECURITY', sql))
    policies = set(
        (p, t) for p, t in re.findall(r'CREATE POLICY "([^"]+)" ON "public"\."([^"]+)"', sql)
    )
    # FKs: parse from ADD CONSTRAINT ... FOREIGN KEY
    fks = {}
    for m in re.finditer(
        r'ALTER TABLE (?:ONLY )?"public"\."([^"]+)"\s+ADD CONSTRAINT "([^"]+)"\s+FOREIGN KEY\s*\(([^)]+)\)\s+REFERENCES\s+"([^"]+)"\."([^"]+)"',
        sql,
    ):
        tbl, cname, col, ref_schema, ref_tbl = m.groups()
        fks[cname] = (tbl, tuple(c.strip().strip('"') for c in col.split(",")), f"{ref_schema}.{ref_tbl}")
    # Columns per table — nested-paren-safe parser.
    columns = {t: _parse_table_columns(sql, t) for t in tables}
    # Absorb ALTER TABLE ADD COLUMN
    for m in re.finditer(r'ALTER TABLE (?:ONLY )?"public"\."([^"]+)" ADD COLUMN "([^"]+)"', sql):
        t, c = m.group(1), m.group(2)
        if t in columns:
            columns[t].add(c)
    return {
        "tables": tables, "views": views, "functions_public": fns,
        "triggers": triggers, "enums_public": enums, "sequences_public": sequences,
        "indexes": indexes, "rls_enabled": rls_enabled, "policies": policies,
        "foreign_keys": fks, "columns": columns,
    }


def _parse_table_columns(sql, table_name):
    """Return set of column names for a given table. Handles nested parens
    (geography(Point,4326), COALESCE(NULLIF(...))) via depth counter."""
    anchor = f'CREATE TABLE IF NOT EXISTS "public"."{table_name}"'
    start = sql.find(anchor)
    if start < 0:
        return set()
    p = sql.find("(", start)
    if p < 0:
        return set()
    depth = 1
    i = p + 1
    end = -1
    while i < len(sql):
        if sql[i] == "(":
            depth += 1
        elif sql[i] == ")":
            depth -= 1
            if depth == 0:
                end = i
                break
        i += 1
    if end < 0:
        return set()
    body = sql[p + 1: end]
    parts = []
    buf = []
    d = 0
    for ch in body:
        if ch == "(":
            d += 1; buf.append(ch)
        elif ch == ")":
            d -= 1; buf.append(ch)
        elif ch == "," and d == 0:
            parts.append("".join(buf).strip()); buf = []
        else:
            buf.append(ch)
    parts.append("".join(buf).strip())
    cols = set()
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if re.match(
            r'^(CONSTRAINT|PRIMARY KEY|UNIQUE|FOREIGN KEY|CHECK|EXCLUDE|LIKE|INHERITS)\b',
            part, re.IGNORECASE,
        ):
            continue
        mm = re.match(r'^"([^"]+)"', part)
        if mm:
            cols.add(mm.group(1))
    return cols


def compare_schemas(live, scratch):
    """Produce a diff structure. Live is source of truth; scratch is what the
    migration chain produces."""
    diff = {
        "summary": {
            "tables_live": len(live["tables"]),
            "tables_scratch": len(scratch["tables"]),
            "views_live": len(live["views"]),
            "views_scratch": len(scratch["views"]),
            "policies_live": len(live["policies"]),
            "policies_scratch": len(scratch["policies"]),
            "fks_live": len(live["foreign_keys"]),
            "fks_scratch": len(scratch["foreign_keys"]),
        },
        "ghost": defaultdict(list),     # live only
        "orphaned": defaultdict(list),  # scratch only
        "attribute_mismatches": defaultdict(list),
    }

    # Table-level: set diff on names.
    diff["ghost"]["tables"] = sorted(live["tables"] - scratch["tables"])
    diff["orphaned"]["tables"] = sorted(scratch["tables"] - live["tables"])

    # Views.
    diff["ghost"]["views"] = sorted(live["views"] - scratch["views"])
    diff["orphaned"]["views"] = sorted(scratch["views"] - live["views"])

    # Functions, triggers, enums, sequences, indexes.
    for k in ("functions_public", "triggers", "enums_public", "sequences_public", "indexes"):
        diff["ghost"][k] = sorted(live[k] - scratch[k])
        diff["orphaned"][k] = sorted(scratch[k] - live[k])

    # RLS state.
    diff["ghost"]["rls_enabled"] = sorted(live["rls_enabled"] - scratch["rls_enabled"])
    diff["orphaned"]["rls_enabled"] = sorted(scratch["rls_enabled"] - live["rls_enabled"])

    # Policies.
    diff["ghost"]["policies"] = sorted(live["policies"] - scratch["policies"])
    diff["orphaned"]["policies"] = sorted(scratch["policies"] - live["policies"])

    # Foreign keys — compared by constraint name.
    live_fk_names = set(live["foreign_keys"].keys())
    scratch_fk_names = set(scratch["foreign_keys"].keys())
    diff["ghost"]["foreign_keys"] = sorted(live_fk_names - scratch_fk_names)
    diff["orphaned"]["foreign_keys"] = sorted(scratch_fk_names - live_fk_names)

    # Column-level drift for tables in both.
    in_both_tables = live["tables"] & scratch["tables"]
    for t in sorted(in_both_tables):
        live_cols = live["columns"].get(t, set())
        scratch_cols = scratch["columns"].get(t, set())
        extra_in_live = live_cols - scratch_cols
        missing_from_live = scratch_cols - live_cols
        if extra_in_live:
            diff["ghost"]["columns"].append({"table": t, "columns": sorted(extra_in_live)})
        if missing_from_live:
            diff["orphaned"]["columns"].append({"table": t, "columns": sorted(missing_from_live)})

    return diff


# -----------------------------------------------------------------------------
# Report output (Phase C)
# -----------------------------------------------------------------------------

def render_text_report(live_env, scratch_info, live_counts, scratch_counts, diff, verbose):
    """Produce the plain-text report."""
    ts = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    host = live_env.get("PGHOST", "?")
    db = live_env.get("PGDATABASE", "?")
    project_ref = host.split(".")[1] if host.count(".") >= 2 else "?"
    # Redact password explicitly; pg host is not secret.

    lines = []
    P = lines.append
    P("=" * 72)
    P("ONYX Schema Drift Report")
    P("=" * 72)
    P(f"Generated:      {ts}")
    P(f"Live target:    postgres://{project_ref}@{host}:{live_env.get('PGPORT','?')}/{db} (password redacted)")
    P(f"Scratch target: local postgres://postgres@127.0.0.1:{SCRATCH_PORT}/verify (dropped on exit)")
    P(f"Script version: {SCRIPT_VERSION}")
    P("")
    P("SUMMARY")
    P(f"  Live:    {live_counts['tables']} tables, {live_counts['views']} views, "
      f"{live_counts['policies']} policies, {live_counts['fks']} FKs")
    P(f"  Scratch: {scratch_counts['tables']} tables, {scratch_counts['views']} views, "
      f"{scratch_counts['policies']} policies, {scratch_counts['fks']} FKs")
    total_ghost = sum(len(v) for v in diff["ghost"].values())
    total_orphan = sum(len(v) for v in diff["orphaned"].values())
    P(f"  Ghost objects (live only):       {total_ghost}")
    P(f"  Orphaned objects (scratch only): {total_orphan}")
    P("")

    def _section(title, bucket, allow_empty=True):
        items = diff[bucket]
        any_content = any(items.get(k) for k in items)
        if not any_content and allow_empty:
            P(f"{title} — none")
            return
        P(title)
        for cat in ("tables", "views", "functions_public", "triggers",
                    "enums_public", "sequences_public", "rls_enabled",
                    "policies", "foreign_keys", "indexes", "columns"):
            entries = items.get(cat) or []
            if not entries:
                continue
            P(f"  {cat}:")
            if cat == "policies":
                for p, t in entries:
                    P(f"    - ON {t}: {p}")
            elif cat == "foreign_keys":
                for c in entries:
                    P(f"    - {c}")
            elif cat == "columns":
                for e in entries:
                    cols = ", ".join(e["columns"])
                    if verbose:
                        P(f"    - {e['table']}: {cols}")
                    else:
                        n = len(e['columns'])
                        preview = ", ".join(e['columns'][:3])
                        more = f", +{n-3} more" if n > 3 else ""
                        P(f"    - {e['table']}: {preview}{more}")
            else:
                for e in entries:
                    P(f"    - {e}")
        P("")

    _section("GHOST OBJECTS (in live, not in active migration chain)", "ghost")
    _section("ORPHANED OBJECTS (in active migration chain, not in live)", "orphaned")

    P("KNOWN LIMITATIONS")
    P("  - PostGIS handling: Option A (extension installed in scratch via CREATE EXTENSION postgis)")
    P("  - Auth stub set: auth.uid(), auth.jwt(), auth.role() stubbed in scratch")
    P("  - Supabase Storage: storage.objects + storage.buckets minimally stubbed (no RLS, no triggers)")
    P("  - Attribute-level drift: basic column-set diff only; type/default/constraint")
    P("    differences are not yet detected (flagged as Phase B follow-up)")
    P("  - Historical migrations under supabase/migrations/historical/ are NOT in the")
    P("    active chain by design (Layer 1 Step 2 Pattern 2)")
    P("")

    if total_ghost == 0 and total_orphan == 0:
        P("EXIT STATUS: clean")
    else:
        P("EXIT STATUS: drift_detected")
        P("")
        P("This script reporting drift means the drift MUST be resolved before")
        P("further schema work. Resolution = either (a) add a migration that captures")
        P("the drift, or (b) revert the out-of-band change in live. See")
        P("scripts/schema_drift_check.md for the drift-resolution rule.")
    P("=" * 72)
    return "\n".join(lines)


def render_json_report(live_env, diff, live_counts, scratch_counts):
    """JSON mirror of the text report hierarchy."""
    total_ghost = sum(len(v) for v in diff["ghost"].values())
    total_orphan = sum(len(v) for v in diff["orphaned"].values())
    payload = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "script_version": SCRIPT_VERSION,
        "summary": {
            "live": live_counts,
            "scratch": scratch_counts,
            "total_ghost": total_ghost,
            "total_orphaned": total_orphan,
        },
        "ghost": {k: _jsonable(v) for k, v in diff["ghost"].items()},
        "orphaned": {k: _jsonable(v) for k, v in diff["orphaned"].items()},
        "attribute_mismatches": {k: _jsonable(v) for k, v in diff["attribute_mismatches"].items()},
        "known_limitations": {
            "postgis_handling": "Option A (CREATE EXTENSION postgis in scratch)",
            "auth_stubs": ["auth.uid()", "auth.jwt()", "auth.role()"],
            "storage_stub": "storage.objects + storage.buckets minimally stubbed",
            "attribute_diff": "column-set only; types/defaults/constraints not yet compared",
            "historical_excluded": "supabase/migrations/historical/ is not in active chain",
        },
        "exit_status": "clean" if total_ghost == 0 and total_orphan == 0 else "drift_detected",
    }
    return json.dumps(payload, indent=2, default=str)


def _jsonable(v):
    if isinstance(v, (set, tuple)):
        return sorted(v)
    if isinstance(v, list):
        return [list(x) if isinstance(x, tuple) else x for x in v]
    return v


# -----------------------------------------------------------------------------
# Self-test
# -----------------------------------------------------------------------------

def self_test_assertions(live, scratch, diff):
    """Assert that the current state matches Step 1 / Step 2 documented
    findings. Returns list of failure strings; empty == pass."""
    failures = []
    exp = SELF_TEST_EXPECTED
    actual_counts = {
        "tables": len(live["tables"]),
        "views": len(live["views"]),
        "functions_public": len(live["functions_public"]),
        "triggers": len(live["triggers"]),
        "policies": len(live["policies"]),
        "enums_public": len(live["enums_public"]),
        "sequences_public": len(live["sequences_public"]),
        "rls_enabled": len(live["rls_enabled"]),
        "foreign_keys": len(live["foreign_keys"]),
    }
    for k, expected in exp.items():
        if k in actual_counts:
            if actual_counts[k] != expected:
                failures.append(
                    f"live.{k}: expected {expected}, got {actual_counts[k]} "
                    f"(live has changed since Step 1, or Step 1 miscounted)"
                )

    # Asserted drift counts — both directions. `ghost_*` / `missing_*` =
    # things in live but not in the active chain (out-of-band additions,
    # the original ghost-schema problem). `orphaned_*` = things declared
    # by the active chain but not present in live (migrations not yet
    # applied, or reverted out of band). Both are drift; both should be
    # zero after Step 2 reconciliation and after any new migrations have
    # been applied to live.
    asserted_drift_counts = {
        # ghost direction (live → chain)
        "ghost_tables": len(diff["ghost"]["tables"]),
        "ghost_columns": sum(len(e["columns"]) for e in diff["ghost"]["columns"]),
        "missing_views": len(diff["ghost"]["views"]),
        "missing_policies": len(diff["ghost"]["policies"]),
        "missing_fks": len(diff["ghost"]["foreign_keys"]),
        # orphaned direction (chain → live)
        "orphaned_tables": len(diff["orphaned"]["tables"]),
        "orphaned_columns": sum(len(e["columns"]) for e in diff["orphaned"]["columns"]),
        "orphaned_foreign_keys": len(diff["orphaned"]["foreign_keys"]),
        "orphaned_policies": len(diff["orphaned"]["policies"]),
        "orphaned_views": len(diff["orphaned"]["views"]),
        "orphaned_rls_enabled": len(diff["orphaned"]["rls_enabled"]),
    }
    for k, expected in exp.items():
        if k in asserted_drift_counts:
            if asserted_drift_counts[k] != expected:
                failures.append(
                    f"{k}: expected {expected}, got {asserted_drift_counts[k]}"
                )
    return failures


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="ONYX schema drift detector (Layer 1 Step 3).")
    parser.add_argument("--verbose", action="store_true",
                        help="Include attribute-level detail in the report")
    parser.add_argument("--no-color", action="store_true",
                        help="No-op; reports are always plain text")
    parser.add_argument("--json", action="store_true",
                        help="Emit JSON with the same hierarchy as the text report")
    parser.add_argument("--self-test", action="store_true",
                        help="Assert expected object counts match Step 1/2 findings")
    parser.add_argument("--live-dump-timeout", type=int, default=900,
                        help="Positive seconds to wait for live pg_dump before failing (default: 900)")
    args = parser.parse_args()
    if args.live_dump_timeout <= 0:
        print("ERROR: --live-dump-timeout must be a positive integer.", file=sys.stderr)
        sys.exit(2)

    preflight()

    # Step 1: discover live credentials (read-only).
    live_env = discover_live_credentials()

    # Step 2: dump live schema.
    work_dir = tempfile.mkdtemp(prefix="onyx_drift_work_")
    _register_cleanup(lambda: shutil.rmtree(work_dir, ignore_errors=True))
    live_dump_path = os.path.join(work_dir, "live.sql")
    dump_live_schema(
        live_env,
        live_dump_path,
        verbose=args.verbose,
        timeout=args.live_dump_timeout,
    )
    with open(live_dump_path) as f:
        live_sql = f.read()

    # Step 3: provision scratch, apply chain, dump.
    scratch_dir = provision_scratch()
    prep_scratch(scratch_dir)
    apply_active_chain(scratch_dir, verbose=args.verbose)
    scratch_dump_path = os.path.join(work_dir, "scratch.sql")
    dump_scratch_schema(scratch_dir, scratch_dump_path)
    with open(scratch_dump_path) as f:
        scratch_sql = f.read()

    # Step 4: parse + diff.
    live = parse_schema(live_sql)
    scratch = parse_schema(scratch_sql)
    diff = compare_schemas(live, scratch)

    live_counts = {
        "tables": len(live["tables"]), "views": len(live["views"]),
        "policies": len(live["policies"]), "fks": len(live["foreign_keys"]),
    }
    scratch_counts = {
        "tables": len(scratch["tables"]), "views": len(scratch["views"]),
        "policies": len(scratch["policies"]), "fks": len(scratch["foreign_keys"]),
    }

    if args.self_test:
        failures = self_test_assertions(live, scratch, diff)
        if failures:
            print("SELF-TEST FAILED:")
            for f in failures:
                print(f"  - {f}")
            print()
            print("--- full drift report follows for diagnosis ---")
            print(render_text_report(live_env, None, live_counts, scratch_counts, diff, True))
            sys.exit(1)
        print("SELF-TEST PASSED — live matches expected; zero ghost (live→chain)")
        print("and zero orphaned (chain→live) across all asserted object types.")
        print(f"  live:    {live_counts}")
        print(f"  scratch: {scratch_counts}")
        sys.exit(0)

    # Step 5: render report.
    if args.json:
        print(render_json_report(live_env, diff, live_counts, scratch_counts))
    else:
        print(render_text_report(live_env, None, live_counts, scratch_counts, diff, args.verbose))

    total_ghost = sum(len(v) for v in diff["ghost"].values())
    total_orphan = sum(len(v) for v in diff["orphaned"].values())
    sys.exit(0 if (total_ghost == 0 and total_orphan == 0) else 1)


if __name__ == "__main__":
    main()
